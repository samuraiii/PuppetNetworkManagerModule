# This defined resource creates the vlan connection keyfile.
#
# @param vlan_id
#   id of the desired vlan REQUIRED
# @param vlan_parent
#   $id of the parent connection managed by this module or the plain UUID (without any prefix like 'UUID=') of the parent connection REQUIRED
#   The parent interface name is not supported, if the parent is not managed by this module find out its UUID yourself and supply it.
# @param ensure
#   state of the interface config DEFAULT: present
# @param state
#   state of the interface (UP/DOWN) not relevant when $ensure == 'absent' DEFAULT: 'up'
# @param id
#   the name of the connection DEFAULT: $title of the resource
# @param interface_name
#   name of the connection interface DEFAULT: $title of the resource
# @param master
#   $id or UUID of the connection master if applicable
# @param slave_type
#   type of the master which this port is a port of (bond, bridge, ...), written as the slave-type (IGNORED if $master == undef)
# @param vlan_flags
#   flags for the 802.1Q vlan protocol DEFAULT: 1
# @param mac_address
#   MAC address of the vlan device, which is the MAC address of its parent unless you changed it. It is used only to build the DHCP DUID
#   (needed by the 'auto' DUID of the IPv6 methods auto and dhcp), it is not written to the keyfile and the device is not looked up by it
# @param ipv4_method
#   what method to use to get an IPv4 address DEFAULT: 'auto', 'disabled' when the vlan is a port ($master)
# @param ipv4_address
#   the IPv4 address with the prefix length and an optional gateway (192.0.2.12/24 or 192.0.2.12/24,192.0.2.1), more addresses as an array or as a string separated by a semicolon
# @param ipv4_dns
#   up to 5 DNS servers for the IPv4: an array of addresses or a string with the addresses separated by a semicolon
# @param ipv4_may_fail
#   is it OK that the IPv4 config fails? DEFAULT: true
# @param ipv4_gateway
#   the IPv4 gateway for the connection
# @param ipv6_method
#   what method to use to get an IPv6 address DEFAULT: 'auto', 'ignore' when the vlan is a port ($master)
# @param ipv6_address
#   the IPv6 address with the prefix length (2001:db8::12/64), more addresses as an array or as a string separated by a semicolon
# @param ipv6_gateway
#   the ipv6 gateway for the connection
# @param ipv6_dns
#   up to 5 DNS servers for the IPv6: an array of addresses or a string with the addresses separated by a semicolon
# @param ipv6_dhcp_duid
#   IPv6 DHCP DUID, 'auto' builds it from the $mac_address, 'unset' writes nothing (NetworkManager default), a NetworkManager keyword or a literal DUID is used as it is DEFAULT: $networkmanager::ipv6_dhcp_duid_default
# @param ipv6_addr_gen_mode
#   IPv6 method for generating of the automatic interface address (0 eui64, 1 stable-privacy, 2 default-or-eui64, 3 default) DEFAULT: 0
# @param ipv6_privacy
#   IPv6 privacy extensions (-1 default, 0 disabled, 1 prefer public, 2 prefer temporary) DEFAULT: 0
# @param ipv6_may_fail
#   is it OK that the ipv6 config fails? DEFAULT: true
# @param additional_config
#   Other not covered configuration
#   In the case when you want to specify special not listed parameters you can add them through
#   $additional_config hash and it will be merged with other parameters.
#   The additional_config has the HIGHEST priority when merged!
#   ie: it will override the defined values of the connection in case of the conflict
#   A setting with an empty string value ('') is not written, like an unset one; the connection.id, uuid, interface-name, master and slave-type can not be overridden
define networkmanager::ifc::vlan (
  Integer[1, 4094]          $vlan_id,
  String                    $vlan_parent,
  Enum['absent', 'present'] $ensure = present,
  Enum['up', 'down']        $state = 'up',
  String                    $id = $title,
  Networkmanager::Interface_name $interface_name = $title,
  Optional[String]          $master = undef,
  Networkmanager::Port_type $slave_type = 'bridge',
  Integer[0, 15]            $vlan_flags = 1,
  Optional[Stdlib::MAC]     $mac_address = undef,
  Optional[Enum['auto', 'dhcp', 'manual', 'disabled', 'link-local']]           $ipv4_method = undef,
  Optional[Networkmanager::IPV4_ADDRESSES]                                     $ipv4_address = undef,
  Optional[Networkmanager::DNS_IPV4]                                           $ipv4_dns = undef,
  Boolean                                                                      $ipv4_may_fail = true,
  Optional[Stdlib::IP::Address::V4::Nosubnet]                                  $ipv4_gateway = undef,
  Optional[Enum['auto', 'dhcp', 'manual', 'ignore', 'link-local', 'disabled']] $ipv6_method = undef,
  Optional[Networkmanager::IPV6_ADDRESSES]                                     $ipv6_address = undef,
  Optional[Stdlib::IP::Address::V6::Nosubnet]                                  $ipv6_gateway = undef,
  Optional[Networkmanager::DNS_IPV6]                                           $ipv6_dns = undef,
  Optional[Networkmanager::DHCP_DUID]                                          $ipv6_dhcp_duid = undef,
  Integer[0, 3]                                                                $ipv6_addr_gen_mode = 0,
  Integer[-1, 2]                                                               $ipv6_privacy = 0,
  Boolean                                                                      $ipv6_may_fail = true,
  Hash                      $additional_config = {},
) {
  include networkmanager


  $uuid = networkmanager::connection_uuid($id)
  $port_settings = { 'connection' => networkmanager::port_settings($master, $slave_type, $id) }
  networkmanager::forbid_uuid_override($additional_config, $id)
  $parent_uuid = networkmanager::connection_uuid($vlan_parent)
  if $parent_uuid == $uuid {
    fail("The vlan_parent '${vlan_parent}' of the connection '${id}' is the connection itself")
  }
  $after = $master ? { undef => [$parent_uuid], default => [$parent_uuid, networkmanager::connection_uuid($master)] }

  # a port of a bridge or a bond has no addresses of its own
  $ipv4_method_w = pick($ipv4_method, $master ? { undef => 'auto', default => 'disabled' })
  $ipv6_method_w = pick($ipv6_method, $master ? { undef => 'auto', default => 'ignore' })

  $ipv6_duid = networkmanager::resolve_ipv6_duid($ipv6_dhcp_duid, $mac_address, $ipv6_method_w, $ensure, $state, $id)

  $ipv4_config = networkmanager::prepare_ipv4_config($ipv4_method_w, $ipv4_address, $ipv4_gateway, $ipv4_dns, $ipv4_may_fail)
  $ipv6_config = networkmanager::prepare_ipv6_config(
    $ipv6_method_w,
    $ipv6_address,
    $ipv6_gateway,
    $ipv6_dns,
    $ipv6_addr_gen_mode,
    $ipv6_privacy,
    $ipv6_may_fail,
    $ipv6_duid
  )

  $keyfile_contents = deep_merge(
    networkmanager::compact_keyfile({
      'connection' => {
        'id'             => $id,
        'uuid'           => $uuid,
        'type'           => 'vlan',
        'interface-name' => $interface_name,
      },
      'vlan'       => {
        'id'     => $vlan_id,
        'flags'  => $vlan_flags,
        'parent' => $parent_uuid,
      },
    }),
    $port_settings,
    $ipv4_config,
    $ipv6_config,
    $additional_config
  )

  networkmanager::connection_manage {
    $id:
      ensure         => $ensure,
      state          => $state,
      content        => $keyfile_contents,
      after          => $after,
      interface_name => $interface_name;
  }
}
