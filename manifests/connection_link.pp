# This defined resource keeps the link of the device of a connection down when the connection has the state 'down',
# or lets NetworkManager manage the device when it has the state 'up'.
# NetworkManager leaves the link administratively UP after the connection is deactivated (or when it was never
# activated), so the link is shut down explicitly. The provider of networkmanager_link does it persistently and unmanages
# the device with `nmcli device set <ifc> managed --permanent down` when NetworkManager supports it, with `ip link`
# otherwise. Bringing it back is done by switching the state to 'up', the device is then managed again before the
# connection is activated. The title is the UUID of the connection.
# It should not be used by user
#
# @param state
#   the state of the connection
# @param ensure
#   'absent' means the connection is removed: the device is given back to NetworkManager (managed), nothing else is ordered
# @param interface_name
#   the name of the device, this or the $mac_address is required
# @param mac_address
#   the MAC address of the device
define networkmanager::connection_link (
  Enum['up', 'down']                       $state,
  Enum['absent', 'present']                $ensure = 'present',
  Optional[Networkmanager::Interface_name] $interface_name = undef,
  Optional[Stdlib::MAC]                    $mac_address = undef,
) {
  assert_private()

  if $title !~ Pattern[/\A\h{8}-(\h{4}-){3}\h{12}\z/] {
    fail("The title of networkmanager::connection_link must be the UUID of the connection, not '${title}'")
  }

  if 'absent' == $ensure {
    # the connection is removed, there is no activation to order the link by
    $link_state = 'managed'
    $link_before = undef
    $link_require = undef
  }
  elsif 'down' == $state {
    # the device is unmanaged after the connection was deactivated
    $link_state = 'down'
    $link_before = undef
    $link_require = Exec["deactivate connection ${title}"]
  }
  else {
    # the device is managed before the connection is activated
    $link_state = 'managed'
    $link_before = Exec["activate connection after initial config ${title}"]
    $link_require = undef
  }

  networkmanager_link {
    "link of connection ${title}":
      interface_name => $interface_name,
      mac_address    => $mac_address,
      state          => $link_state,
      before         => $link_before,
      require        => $link_require;
  }
}
