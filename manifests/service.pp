# This class manages NetworkManager services
# Not to be used by user
#
# @param wait_online
#   Taken from `$networkmanager::wait_online`. The wait-online unit exists only with systemd (the `service_provider` fact of
#   stdlib is `systemd`): `true` starts and enables it, `false` stops and disables it there, other service managers
#   (OpenRC, ...) and hosts without the fact have no such unit and it is not managed
class networkmanager::service (
  Boolean $wait_online = $networkmanager::wait_online,
) {
  assert_private()

  # managing a unit which does not exist could fail the run (OpenRC), so the wait-online unit is left alone elsewhere
  if 'systemd' == $facts['service_provider'] {
    $wait_ensure = $wait_online ? {
      true    => running,
      default => stopped,
    }
    service { 'NetworkManager-wait-online':
      ensure => $wait_ensure,
      enable => $wait_online,
    }
  }

  service { 'NetworkManager':
    ensure => running,
    enable => true,
  }
}
