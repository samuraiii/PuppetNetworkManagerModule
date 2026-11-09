# This class sets the OS specific variables (package names) of the networkmanager module.
# Not to be used by user
#
# @summary OS specific variables for the networkmanager module
class networkmanager::os () {
  assert_private()

  # a host without the os.family fact takes the unsupported way (fails, or the warning with ignore_unsupported_os)
  $family = String($facts.dig('os', 'family'))
  $os_family = downcase($family)
  case $os_family {
    'archlinux': {
      $package_name = 'networkmanager'
      $extra_packages = []
    }
    'debian': {
      $package_name = 'network-manager'
      $extra_packages = []
    }
    'redhat': {
      $package_name = 'NetworkManager'
      $extra_packages = []
    }
    'gentoo': {
      $package_name = 'net-misc/networkmanager'
      $extra_packages = []
    }
    default: {
      if $networkmanager::ignore_unsupported_os {
        # no package is managed, NetworkManager has to be installed by other means
        warning("The OS family '${family}' is not supported by the networkmanager module, the package is not managed")
        $package_name = undef
        $extra_packages = []
      }
      else {
        fail("The OS family '${family}' is not supported by the networkmanager module (ignore_unsupported_os => true skips the package installation)")
      }
    }
  }
}
