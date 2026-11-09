# This class manages NetworkManager services
# Not to be used by user
#
# @param wait_online
#   Taken from `$networkmanager::wait_online`, `false` stops and disables the wait-online unit on systemd hosts, it
#   leaves the service manager of other hosts alone
class networkmanager::service (
  Boolean $wait_online = $networkmanager::wait_online,
) {
  assert_private()

  # the wait-online unit is switched off only where systemd has it, a service manager without the unit (OpenRC) has
  # nothing to switch off and could refuse to manage the unknown service
  if $wait_online {
    service { 'NetworkManager-wait-online':
      ensure => running,
      enable => true,
    }
  }
  elsif 'systemd' == $facts['service_provider'] {
    service { 'NetworkManager-wait-online':
      ensure => stopped,
      enable => false,
    }
  }
  service { 'NetworkManager':
    ensure => running,
    enable => true,
  }
}
