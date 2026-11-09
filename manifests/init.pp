# This is main class of the network manager puppet module and
# you can define here nm module behaviour setting up parameters:
# @example
#   include networkmanager
#
# @param erase_unmanaged_keyfiles
#   If you want to remove puppet unmanaged keyfiles (*.nmconnection) from the $connections_dir directory DEFAULT: false
# @param connections_dir
#   the directory with the connection keyfiles DEFAULT: /etc/NetworkManager/system-connections
# @param no_auto_default
#   If you want to add no-auto-default=* option inside main /etc/NetworkManager/NetworkManager.conf config file. DEFAULT: false
#   (only the wildcard is supported, use the $additional_config for a list of devices)
# @param install_package
#   Install the NetworkManager package (the OS package manager is used) DEFAULT: true
# @param ignore_unsupported_os
#   do not fail on an operating system family the module has no package name for, the package is not managed then
#   (install NetworkManager by other means) DEFAULT: false
# @param version
#   version string for NetworkManager version you want to install
# @param unmanaged_devices
#   Array of the devices you want the NetworkManager to ignore (as name or mac address, you can mix it)
# @param wait_online
#   enable the NetworkManager-wait-online service DEFAULT: true, false stops and disables it on systemd hosts and leaves other service managers alone
# @param use_internal_resolv_conf
#   use the networkmanager bundled resolver
# @param plugins
#   should we use different plugins to get network config data (NOT RECOMMENDED TO CHANGE)
# @param max_length_of_connection_id
#   Limit the name of the connection to this length. DEFAULT: 15 characters
#   to comply with kernel interface name limits since the connection $id is used as default
#   for the connection $interface_name, if you change this you need to take care to supply
#   the $interface_name with length < 16 characters where applicable
# @param duid_prefix
#   allows the change of the duid prefix to anything other with format "aa:bb:cc:dd" (downcased)
# @param ipv6_dhcp_duid_default
#   the IPv6 DHCP DUID used for the connections which do not set their own $ipv6_dhcp_duid DEFAULT: 'auto'
#   'auto' builds it from the mac address of the connection (the connection needs the $mac_address), 'unset' writes nothing so NetworkManager
#   uses its own default, the NetworkManager keywords (ll, llt, lease, stable-ll, stable-llt, stable-uuid) or a literal DUID (aa:bb:cc:...) are used as they are
# @param show_diff
#   show the diffs of the keyfiles and of the NetworkManager.conf when they change (with the secrets censored, and only when the
#   `show_diff` setting of Puppet is enabled as it is for the file resource) DEFAULT: true
# @param secret_keys
#   names of the settings whose values are censored in the diffs in addition to the built in ones (passwords, psk, wep keys,
#   private keys, everything in the vpn-secrets section, ...) DEFAULT: []. A name matches every setting that contains it (case insensitive),
#   so `key` censors all the settings with `key` in the name
# @param additional_config
#   Configuration hash for the NetworkManager.conf, it is able to override default module config in case of conflict!
# @param uuid_seed
#   the text the UUIDs of the connections are derived from together with their ids, DEFAULT: the certname of the node (the fqdn fact without it).
#   Set it to keep the UUIDs when the node gets another certname (a reinstall), or to give the same connection the same UUID on more nodes.
class networkmanager (
  Boolean                                  $erase_unmanaged_keyfiles = false,
  Stdlib::Absolutepath                     $connections_dir = '/etc/NetworkManager/system-connections',
  Boolean                                  $no_auto_default = false,
  Boolean                                  $install_package = true,
  Boolean                                  $ignore_unsupported_os = false,
  Optional[String[1]]                      $version = undef,
  Array[Networkmanager::Unmanaged_device]  $unmanaged_devices = [],
  Boolean                                  $wait_online = true,
  Optional[Variant[Boolean, Enum['stub']]] $use_internal_resolv_conf = undef,
  Array[Networkmanager::Plugin]            $plugins = ['keyfile'],
  Integer[3]                               $max_length_of_connection_id = 15,
  Pattern[/\A\h{2}(:\h{2}){3}\z/]          $duid_prefix = '00:03:00:01',
  Networkmanager::DHCP_DUID                $ipv6_dhcp_duid_default = 'auto',
  Boolean                                  $show_diff = true,
  Array[String]                            $secret_keys = [],
  Hash                                     $additional_config = {},
  Optional[String[1]]                      $uuid_seed = undef,
) {
  $node_id = [
    $trusted['certname'],
    $facts['clientcert'],
    $facts.dig('networking', 'fqdn'),
  ].filter |$hn| { $hn =~ String[1] }[0]
  if undef == $node_id and undef == $uuid_seed {
    fail('The networkmanager module needs the certname of the node (or the fqdn fact), or the uuid_seed, to generate the stable UUIDs of the connections')
  }
  # the UUIDs of the connections are derived from this, the node name by default
  $sys_id = $uuid_seed ? { undef => $node_id, default => $uuid_seed }
  $duid_prefix_d = $duid_prefix.downcase
  # the tag of the virtual activation execs of this node, they are collected by networkmanager::reload
  $activation_tag = "nmactivate-2022b07${node_id}"
  # the subclasses are contained, so ordering something after Class['networkmanager'] means after the
  # package, the configuration and the service
  contain networkmanager::os

  contain networkmanager::install

  contain networkmanager::config

  contain networkmanager::service

  Class['networkmanager::os']
  -> Class['networkmanager::install']
  -> Class['networkmanager::config']
  -> Class['networkmanager::service']
}
