# This class handles the installation of the NetworkManager packages
# Not to be used by user
#
# @param install_package
#   Taken from `$networkmanager::install_package`
# @param package_name
#   Taken from `$networkmanager::os::package_name`
# @param extra_packages
#   Taken from `$networkmanager::os::extra_packages`
# @param install_extra_packages
#   Taken from `$networkmanager::install_package`
# @param version
#   Taken from `$networkmanager::version`
class networkmanager::install (
  Boolean          $install_package = $networkmanager::install_package,
  Optional[String] $package_name = $networkmanager::os::package_name,
  Array            $extra_packages = $networkmanager::os::extra_packages,
  Boolean          $install_extra_packages = $networkmanager::install_package,
  Optional[String[1]] $version = $networkmanager::version,
) {
  assert_private()

  if $version {
    $ensure_nm_install = $version
  }
  else {
    $ensure_nm_install = present
  }

  # a new version of the package restarts the daemon
  if $install_package and $package_name {
    package {
      $package_name:
        ensure => $ensure_nm_install,
        notify => Service['NetworkManager'];
    }
  }
  if $install_extra_packages and $extra_packages != [] {
    package {
      $extra_packages:
        ensure => present,
        notify => Service['NetworkManager'];
    }
  }
}
