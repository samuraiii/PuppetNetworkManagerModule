# networkmanager

[![CI](https://img.shields.io/github/actions/workflow/status/samuraiii/PuppetNetworkManagerModule/ci.yml?branch=main&label=CI)](https://github.com/samuraiii/PuppetNetworkManagerModule/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/samuraiii/PuppetNetworkManagerModule)](https://github.com/samuraiii/PuppetNetworkManagerModule/releases)
[![Puppet Forge version](https://img.shields.io/puppetforge/v/samuraiii/networkmanager)](https://forge.puppet.com/modules/samuraiii/networkmanager)
[![Puppet Forge downloads](https://img.shields.io/puppetforge/dt/samuraiii/networkmanager)](https://forge.puppet.com/modules/samuraiii/networkmanager)
[![License: MIT](https://img.shields.io/github/license/samuraiii/PuppetNetworkManagerModule)](LICENSE)
[![Issues](https://img.shields.io/github/issues/samuraiii/PuppetNetworkManagerModule)](https://github.com/samuraiii/PuppetNetworkManagerModule/issues)


## Table of Contents

1. [Disclaimer](#disclaimer)
1. [Description](#description)
    * [Who it is for](#who-it-is-for)
1. [Setup - The basics of getting started with networkmanager](#setup)
    * [What networkmanager module affects](#what-networkmanager-module-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with networkmanager](#beginning-with-networkmanager)
1. [Usage](#usage)
1. [Reference](#reference)
1. [Connection id length](#connection-id-length)
1. [IPv6 DHCP DUID](#ipv6-dhcp-duid)
1. [Interface of the connection](#interface-of-the-connection)
1. [Multiple IP addresses](#multiple-ip-addresses)
1. [VLAN parent connection](#vlan-parent-connection)
1. [Master and slave_type](#master-and-slave_type)
1. [Stable identifiers and addresses (server defaults)](#stable-identifiers-and-addresses-server-defaults)
1. [Order and state of the connections](#order-and-state-of-the-connections)
1. [Unsupported operating systems](#unsupported-operating-systems)
1. [Known limitations and gotchas](#known-limitations-and-gotchas)
1. [Development](#development)
1. [Use of AI tools](#use-of-ai-tools)
1. [Acknowledgements](#acknowledgements)
1. [Contact](#contact)


## Disclaimer

This repository is the continuation of [jednoprsak/PuppetNetworkManagerModule](https://github.com/jednoprsak/PuppetNetworkManagerModule), which is not developed any more (v1.1.0 was the last release published there). The development, the releases, the issues and the pull requests are here. The name of the module (eg. for a `Puppetfile`) is `samuraiii-networkmanager` since 1.1.1, it was `jednoprsak-networkmanager`.

This is a FOSS project, the work on it is done either in free time or as a part of a daily job which is not focused on developing this code. The issues will be fixed as soon as time allows, it can take more time than you would expect. The code is still actively used on 300+ machines, so any problems found are fixed and will eventually be shared here. If you have a problem please create an issue, or a pull request if you can.
Writing e-mails to the authors won't help.

## Description

You want to use our module because no one had written another module for using keyfiles yet (October 18, 2022) and we from Prague Academy of Physics computing farm geeks are the best underground team ever, but stop flexing. I hope that this module will be usable for you. The module installs NetworkManager, configures its config file, starts the service, creates keyfiles and pushes them inside NetworkManager via nmcli (and nmcli pushes them inside via dbus). It provides a few defined resources to create keyfiles for a connection (dhcp, static, ipv6, ipv4), bridge, bond and vlan, and a fallback defined resource for a user defined keyfile.

### Who it is for
The module is made for **servers**. A server must be recognised by the network: the DHCP server has to hand out the same address to the same host after a reinstall, a reboot or a new profile, and the host must not change its identity on its own. That is why the defaults are the opposite of what a desktop distribution does:

* the DHCPv6 client identifier (DUID) is built from the MAC address of the host. It is the only identifier a DHCPv6 server can bind an address to; the default of NetworkManager and of the distributions is a random value made on the first boot, unrelated to anything that identifies the host, so the address is lost with the profile or the installation (see [IPv6 DHCP DUID](#ipv6-dhcp-duid)),
* the IPv6 addresses are the stable EUI-64 ones and the privacy extensions (temporary addresses) are off,
* the UUIDs of the connections are derived from the name of the node and of the connection, not random,
* the module therefore asks for the MAC address of the connections that use the DHCPv6 DUID, instead of silently leaving the identity to chance.

You can manage workstations and laptops with it too: everything above can be changed (`ipv6_dhcp_duid_default: unset`, `ipv6_addr_gen_mode`, `ipv6_privacy`, the `additional_config`), see [Stable identifiers and addresses](#stable-identifiers-and-addresses-server-defaults).

The module supports both Puppet and [OpenVox](https://voxpupuli.org/openvox/), the community fork of Puppet by Vox Pupuli, and is tested with both.


## Setup

### What networkmanager module affects

* The NetworkManager package, whose name is chosen by the OS family (Debian, RedHat, Arch Linux and Gentoo families are supported).
* The `NetworkManager` and `NetworkManager-wait-online` services (running and enabled, `Service['NetworkManager']` and `Service['NetworkManager-wait-online']`). `wait_online => false` stops and disables the wait-online unit on systemd hosts and leaves the service manager of other hosts alone.
* `/etc/NetworkManager/NetworkManager.conf`, which is fully managed (plugins, `no-auto-default`, `unmanaged-devices` and your own `additional_config`) by the `networkmanager_keyfile` resource.
  The `unmanaged_devices` are MAC addresses or interface names (up to 15 printable ASCII characters, globs like `docker*` are allowed, `/`, `\`, `:` and `;` are not) and the `plugins` are lowercase plugin names like `keyfile` or `ifcfg-rh`.
* `/etc/NetworkManager/system-connections/`, which holds one `<id>.nmconnection` keyfile (mode `0600`, a `networkmanager_keyfile` resource) per connection. The directory can be changed by `connections_dir`. With `erase_unmanaged_keyfiles => true` (`false` by default, nothing is removed then) every `*.nmconnection` file in that directory which is not managed by Puppet is deleted (other files are left alone) (by the `networkmanager_keyfile_dir` resource).
* `/etc/resolv.conf`, only when `use_internal_resolv_conf` is set: it is then linked to the resolver file generated by NetworkManager (`true` or `'stub'`) or turned into a plain file (`false`; a link is replaced by a copy of the file it points to, so the file is never empty; a dangling link has nothing to copy and is replaced by an empty file, which NetworkManager fills in when it rewrites the resolver).
* The state of the connections: after a keyfile changes, the module reloads the NetworkManager connections and activates or deactivates the connection with `nmcli` (through an `exec` that waits for the NetworkManager D-Bus service via `gdbus`). A connection (every `networkmanager::ifc::*` define that has an `interface_name` or a `mac_address`; for `::fallback` they are parameters used only for the link, not written to the keyfile) with `state => 'down'` also gets its link set down by the `networkmanager_link` resource: NetworkManager supporting `nmcli device set <ifc> managed --permanent` (1.57 and newer, also backported by RHEL 9.9 / 10.3) gets it with `down` (the device becomes unmanaged and administratively down, persistently; switching back to `'up'` runs `managed --permanent yes`; the link is shut down with `ip` too when it stayed up), the others `ip link` (switching back to `'up'` brings the link up). The way is chosen when the catalog is applied.

### Setup Requirements

* Puppet `>= 4.9.2 < 9.0.0` or [OpenVox](https://voxpupuli.org/openvox/) `>= 7.0.0 < 9.0.0` (the community fork of Puppet by Vox Pupuli, tested in the CI as well).
* The `puppetlabs/stdlib` module `>= 5.2.0 < 11.0.0` (required: the module uses its IP address and MAC types and the `deep_merge` function).
* On the managed node: `nmcli` (installed with NetworkManager), `/usr/bin/gdbus` (from GLib, present on all supported systems; the path is not configurable) and, for `state => 'down'` with NetworkManager without that support, `ip` (iproute2).

### Diffs and secrets

The keyfiles and the NetworkManager.conf are `networkmanager_keyfile` resources: the module hands the sections to the provider, which renders the file when the catalog is applied. A change is logged with the checksums of the content and, when the `show_diff` setting of Puppet is on (as for the `file` resource), with a diff. The values of the secrets (passwords, `psk`, wep keys, private keys, the `vpn-secrets` section, ...) are replaced by `<redacted>` in the diff, and a change of a secret only is reported as such. `show_diff => false` of the `networkmanager` class silences the diffs completely, `secret_keys => ['my-setting']` censors more settings. `puppet resource networkmanager_keyfile` shows only the checksums.

The secrets you give to the module (eg. a `psk` in `additional_config`) are plain data in the compiled catalog, as the content of a `file` resource is, and the module does not accept `Sensitive` values: nested `Sensitive` leaves are lost without the rich data catalog serialization, and a `Sensitive` content would hide the whole diff of the keyfile, so it was decided not to support it. Keep the secrets out of the catalog and of the reports by other means: encrypt them in Hiera (eg. `hiera-eyaml`), restrict the access to the Puppet server, PuppetDB and the reports, and list the unusual setting names in `secret_keys` so that they are censored in the diffs.

### Beginning with networkmanager

When you want to begin with NetworkManager, you need to be clever as devil, but
our module will help you create keyfiles and push them inside that oven of hell.

## Usage
```puppet

class {
  'networkmanager':
    erase_unmanaged_keyfiles => true,
    no_auto_default          => true;
}

networkmanager::ifc::connection {
  'zone1':
    ensure         => present,
    mac_address    => '00:00:5e:00:53:01',
    ipv4_method    => 'manual',
    ipv4_address   => '192.0.2.12/24,192.0.2.1',
    ipv4_dns       => '192.0.2.53;192.0.2.54;',
    ipv6_method    => 'manual',
    ipv6_dhcp_duid => 'auto',
    ipv6_address   => '2001:db8::12/64',
    ipv6_dns       => '2001:db8::53;2001:db8::54;',
    ipv6_gateway   => '2001:db8::1';
}

networkmanager::ifc::bridge {
  'bridge1':
    ensure      => present,
    ipv6_method => 'ignore';
}

networkmanager::ifc::bridge::slave {
  'bridge1-slave':
    ensure      => present,
    mac_address => '00:00:5e:00:53:02',
    master      => 'bridge1';
}

networkmanager::ifc::bond {
  'bondmaster2':
    ensure            => present,
    ipv4_method       => 'auto',
    ipv6_method       => 'ignore',
    bond_mode         => 'balance-xor',
    additional_config => {
      bond => {
        miimon => '100',
      }
    };
}

networkmanager::ifc::bond::slave {
  'bondslaveens8':
    ensure      => present,
    mac_address => '00:00:5e:00:53:03',
    master      => 'bondmaster2';
}

networkmanager::ifc::bond::slave {
  'bondslaveens9':
    ensure      => present,
    mac_address => '00:00:5e:00:53:04',
    master      => 'bondmaster2';
}
```

## Reference
The classes, defined types, resource types, functions and data types with their parameters are described in [REFERENCE.md](REFERENCE.md), which is generated from the comments of the code by `bundle exec puppet strings generate --format markdown --out REFERENCE.md` (Ruby 3.1 or newer), do not edit it by hand.

## Connection id length
The `connection.id` parameter is limited by default to 15 characters, because it is by default used also as the interface name.
The interface name has an upper limit of 15 characters set by the kernel.
You can override this limit by setting `$networkmanager::max_length_of_connection_id` to the value you like, but then you need to set, where applicable, the `connection.interface-name` to something that is less than 16 characters long.

The `id` is also the name of the keyfile, so it may contain only printable ASCII characters (the space is allowed), except `/` and `\`, and it must not start with a dot.

## IPv6 DHCP DUID
For a connection with the `auto` or `dhcp` IPv6 method the DHCP DUID (`ipv6.dhcp-duid`) is written to the keyfile (for a present connection in the state `up` and `down` alike, it is the identity of the profile), because the default DUID of NetworkManager is random and would break getting the right lease from the DHCP server. The DUID is the only way a DHCPv6 server can tie an address to a host (the IPv4 DHCP needs the MAC address of the host the same way), so it is built from the MAC address, the same one the IPv4 DHCP server knows.
The `ipv6_dhcp_duid` of the connection is used, and when it is not set the `ipv6_dhcp_duid_default` of the `networkmanager` class (`'auto'` by default):

* `'auto'`: the DUID is built from the `mac_address` of the connection and the `duid_prefix` of the class (`00:03:00:01:<mac>`), the connection then needs the `mac_address` (also a bond, a bridge and a vlan: give it the MAC address the host has on that interface, a vlan has the MAC address of its parent unless you changed it; it is used only to build the DUID, it is not written to the keyfile). The same MAC address on the parent and on its vlans gives them the same DUID, give a vlan a literal `ipv6_dhcp_duid` when its DHCP server must tell them apart,
* `'unset'`: nothing is written and NetworkManager uses its own default (`lease`), no `mac_address` is needed,
* `ll`, `llt`, `lease`, `stable-ll`, `stable-llt`, `stable-uuid`: the NetworkManager keyword is written as it is,
* a literal DUID (`00:03:00:01:aa:bb:cc:dd:ee:ff`): written as it is (the same DUID on all the connections that use the default).

```yaml
# workstations and laptops (Hiera): let NetworkManager decide
networkmanager::ipv6_dhcp_duid_default: unset
```

## Interface of the connection
An ethernet connection (`networkmanager::ifc::connection`) is bound to an interface by `interface_name` (`interface-name`) and/or `mac_address`. When neither is given, the title of the resource is used as the interface name, so `networkmanager::ifc::connection { 'ens192': ipv4_method => 'auto', ipv6_method => 'ignore' }` configures the interface `ens192`. The title must then be usable as the interface name (1 to 15 printable ASCII characters, no whitespace, `/`, `\`, `:`, `*`, `?`, `[` or `]`, starting with a letter or a digit, not `all` or `default`), otherwise set `interface_name` or `mac_address`.
With only `mac_address` no interface name is written (the connection is bound by the MAC address only).

## Multiple IP addresses
`ipv4_address` and `ipv6_address` of the `networkmanager::ifc::connection`, `::bond` and `::bridge` accept one address with the prefix length (written as `address=`, for IPv4 optionally followed by a gateway like `192.0.2.12/24,192.0.2.1`), or more addresses given as an array or as a string separated by a semicolon.
More addresses are written to the keyfile as `address1=`, `address2=` and so on, which is how NetworkManager stores them itself.

```puppet
networkmanager::ifc::connection {
  'ens192':
    interface_name => 'ens192',
    ipv4_method    => 'manual',
    ipv4_address   => ['198.51.100.57/24', '198.51.100.234/24'],
    ipv4_gateway   => '198.51.100.1',
    ipv6_method    => 'disabled';
}
```

## VLAN parent connection
The `vlan_parent` parameter of `networkmanager::ifc::vlan` is either the `$id` of a connection managed by this module (it is converted to that connection's UUID) or the plain UUID of the parent connection, written to the keyfile as `parent=<uuid>` (NetworkManager does not accept any prefix like `UUID=`).

The vlan has the IP parameters of `networkmanager::ifc::connection` (`ipv4_*`, `ipv6_*`), with the same defaults (`auto`, and the stable IPv6 settings); a vlan with a `master` is a port and gets `disabled`/`ignore`. As for the other connections the DHCP DUID of the IPv6 methods `auto` and `dhcp` is built from the `mac_address` of the vlan (the MAC address of its parent, see [IPv6 DHCP DUID](#ipv6-dhcp-duid)); it is used only for the DUID.
The name of the parent interface is deliberately not supported: if the parent is not managed by this module, you need to find out its UUID yourself (eg. `nmcli -g connection.uuid connection show <name>`) and supply it.

## Master and slave_type
A connection which is a port of another connection (a bond into a bridge, a vlan into a bridge, an ethernet connection into a bond) has the `master` (the `$id` or the UUID of the controller connection) and the type of the controller, the `slave_type` (`bond`, `bridge`, `team`, `ovs-bridge`, `ovs-port` or `vrf`), which is written as the `slave-type`.
NetworkManager refuses a keyfile with a controller and without the type of it (`connection.port-type: Cannot set 'controller' without 'port-type'`), so the `slave_type` is **required with the `master`** of `networkmanager::ifc::connection`, `::bond` and `::bridge` (the compilation fails without it), and it is ignored without the `master`.
`networkmanager::ifc::vlan` has the `slave_type` `'bridge'` by default, the `::bond::slave` and `::bridge::slave` have the type fixed.

```puppet
# a bond which is a port of a bridge
networkmanager::ifc::bond {
  'bond0':
    ipv6_method => 'ignore',
    master      => 'br0',
    slave_type  => 'bridge';
}
```

## Stable identifiers and addresses (server defaults)
The module aims primarily at servers, where the identifiers and the addresses of a host must not change:

* the `ipv6_addr_gen_mode` of the connections is `0` (EUI-64, the interface identifier is derived from the MAC address) and the `ipv6_privacy` is `0` (no temporary addresses), both are always written to the keyfile of the `auto`, `dhcp`, `manual` and `link-local` IPv6 methods instead of leaving the choice to the NetworkManager or the distribution default (`stable-privacy`, temporary addresses),
* the DHCP DUID is derived from the MAC address by default (see [IPv6 DHCP DUID](#ipv6-dhcp-duid)),
* the UUIDs of the connections are derived from the certname of the node and the `id` of the connection; set `networkmanager::uuid_seed` to derive them from another text, eg. to keep them when the node gets another certname (a reinstall) or to give the same connection the same UUID on several nodes. Changing the seed changes the UUIDs of all the connections.

All of them can be changed: set `ipv6_addr_gen_mode` (0 to 3, see `nmcli` `ipv6.addr-gen-mode`) and `ipv6_privacy` (-1 to 2) on the connection, `ipv6_dhcp_duid` or the `ipv6_dhcp_duid_default` of the class, or override anything in the `additional_config` of the connection (it wins over every other parameter).

## Order and state of the connections
* The subclasses of `networkmanager` are contained: a relationship to `Class['networkmanager']` means after the package, the configuration and the services.
* A connection is activated after its master or parent connection when that one is managed by this module (`master` of a connection, bond, bridge, the `master` of the slaves, `master` and `vlan_parent` of a vlan).
* `state => 'up'` activates the connection (when the keyfile changed, and in every run when it is not active), `state => 'down'` deactivates it when it is active, in every run, and shuts its link down, see the setup section. NetworkManager may bring a down connection of a device that is not unmanaged up again by itself between the runs, the next run deactivates it again.
* `ensure => 'absent'` deactivates the connection, removes its keyfile and makes NetworkManager forget the profile (the last step is repeated by every run while NetworkManager still knows the profile, so an interrupted removal is finished). When the connection has an `interface_name` or a `mac_address`, its device is given back to NetworkManager (`managed`), so a device unmanaged by an earlier `state => 'down'` does not stay so.
* A `master` or `vlan_parent` that is the connection itself is refused. Two connections that name each other as the master are a dependency cycle, which Puppet reports with the UUIDs of the activation execs.

## Unsupported operating systems
The module fails on an operating system family it has no package name for (Debian, RedHat, Arch Linux and Gentoo families are supported). Set `networkmanager::ignore_unsupported_os: true` to skip the package installation on such a system (a warning is logged) and install NetworkManager by other means, the rest of the module (the configuration, the services, the connections) works as usual.

## Known limitations and gotchas
* **Retries of the connections that cannot come up.** The `activate connection always` exec tries to activate the connections that are `up` in every run, and each try does a global `nmcli connection reload` and waits for the result. A connection that can never come up (no carrier, a missing parent device, an interface that is not there yet) is retried, and slows down, every run. Use `state => 'down'`, `ensure => 'absent'` or `ipv4_may_fail`/`ipv6_may_fail` for such connections. A bounded wait for the activation is a TODO.
* **Unknown devices of `networkmanager_link`.** The state of a device that does not exist (a typo in the `interface_name`, an interface that is not renamed yet, no device with the `mac_address`) is reported as `down`, so a `down` link is in sync and a `managed` one is in sync too. The activation of the connection fails later instead. Check the interface names, the module does not.
* **The master or the parent given by the id is converted to a UUID without a check** that a connection with that id exists: an interface name or a typo gives a valid but unknown UUID and NetworkManager fails at the activation.
* **A setting with an empty string value is not written** (the `additional_config` of the connections too), it is taken as not set. `puppet resource networkmanager_keyfile` lists only the default `connections_dir`, and a name in `secret_keys` censors every setting that contains it.
* **Raw `additional_config` is written as it is.** The names of the sections and the settings are validated against the injection of the keyfile syntax, but a setting NetworkManager does not know is silently ignored by it.
* **The `mac_address` of a bond, a bridge or a vlan** is used only to build the DUID, it is not written to the keyfile. The compilation fails without it for the IPv6 methods `auto` and `dhcp` (unless the DUID is `unset` or a literal), on purpose: a DUID nobody chose is a random one.

## Development
The tests are in `spec/` and the same checks as in the GitHub Actions workflow (`.github/workflows/ci.yml`) can be run locally:

```sh
bundle install
bundle exec metadata-json-lint metadata.json
bundle exec rake syntax lint          # the lint fails on warnings
git clone --depth 1 --branch v9.7.0 https://github.com/puppetlabs/puppetlabs-stdlib.git spec/fixtures/modules/stdlib
bundle exec rake spec
```

`PUPPET_GEM_VERSION` (eg. `'~> 7.0'`) or `OPENVOX_GEM_VERSION` selects the version of Puppet or OpenVox for the `bundle install`, the version of `stdlib` is the one you clone into `spec/fixtures/modules/stdlib` (`.fixtures.yml` pins `v9.7.0` for `rake spec_prep`, the CI clones the `STDLIB_REF` of its matrix).

OpenVox 8.24 and newer (including 9) do not work with `puppetlabs_spec_helper` and `puppet-syntax` (they depend on the `puppet` gem), so the `Gemfile` leaves them out when `OPENVOX_GEM_VERSION` is `8.x` or `9.x` and `rspec-puppet` is used directly:

```sh
OPENVOX_GEM_VERSION='>= 9.0.0.pre.alpha' bundle install   # or '~> 8.0'
bundle exec rake spec_prep                                  # clones the fixtures and links the module
bundle exec rspec spec/classes spec/defines spec/functions spec/type_aliases spec/unit
bundle exec puppet-lint --no-140chars-check --no-documentation-check manifests functions types
```
The specs generate the facts of every operating system release listed in `operatingsystem_support` of `metadata.json` (`spec/spec_helper_local.rb`), so a release added there is tested automatically.

## Use of AI tools
Contributions prepared with the help of AI tools (code assistants, chat bots and similar) are welcome.
The submitter is fully responsible for everything they submit, regardless of how it was produced:
review, understand and test the change yourself, make sure it passes the checks in `.github/workflows/ci.yml`,
and that you have the right to submit it under the license of this module.
Pull requests that look like unreviewed AI output can be closed without a detailed review.

## Acknowledgements
Many thanks to [MetaCentrum](https://metacentrum.cz/) for the LLM service used for the AI-assisted review of this module.

> Computational resources were provided by the e-INFRA CZ project (ID:90254),
> supported by the Ministry of Education, Youth and Sports of the Czech Republic.

## Contact

Use the issues on GitHub: https://github.com/samuraiii/PuppetNetworkManagerModule/issues

