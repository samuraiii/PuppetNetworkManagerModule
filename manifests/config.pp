# This class configures file /etc/NetworkManager/NetworkManager.conf (the networkmanager_keyfile resource),
# sets up whether to erase unmanaged keyfiles, and adds no-auto-default option
# inside config file according to no_auto_default parameter defined at the entrance
# of networkmanager class.
# It is not recommended to use it without main networkmanager class.
#
# @param erase_unmanaged_keyfiles
#   Taken from `$networkmanager::erase_unmanaged_keyfiles`
# @param no_auto_default
#   Taken from `$networkmanager::no_auto_default`
# @param unmanaged_devices
#   Taken from `$networkmanager::unmanaged_devices`
# @param plugins
#   Taken from `$networkmanager::plugins`
# @param use_internal_resolv_conf
#   Taken from `$networkmanager::use_internal_resolv_conf`
# @param additional_config
#   Settings merged over the NetworkManager.conf built by the module, they win in case of a conflict.
#   Taken from `$networkmanager::additional_config`

class networkmanager::config (
  Boolean                               $erase_unmanaged_keyfiles = $networkmanager::erase_unmanaged_keyfiles,
  Variant[Boolean,String]               $no_auto_default = $networkmanager::no_auto_default,
  Array[String]                         $unmanaged_devices = $networkmanager::unmanaged_devices,
  Array[String]                         $plugins = $networkmanager::plugins,
  Optional[Variant[Boolean, Enum['stub']]] $use_internal_resolv_conf = $networkmanager::use_internal_resolv_conf,
  Hash                                  $additional_config = $networkmanager::additional_config,
) {
  $main_conf_file = '/etc/NetworkManager/NetworkManager.conf'
  if $unmanaged_devices != [] {
    $unmanaged_devices_c = join($unmanaged_devices.map |$dev| {
      if $dev =~ Stdlib::MAC {
        "mac:${dev}"
      }
      else {
        "interface-name:${dev}"
      }
    }, ';')
    $unmanaged = { 'keyfile' => { 'unmanaged-devices' => $unmanaged_devices_c } }
  }
  else {
    $unmanaged = {}
  }
  if $no_auto_default {
    $nauto = $no_auto_default ? {
      true    => '*',
      default => $no_auto_default,
    }
    $noauto = { 'main' => { 'no-auto-default' => $nauto } }
  }
  else {
    $noauto = {}
  }
  $default_config = { 'main' => { 'plugins' => join($plugins, ',') } }

  $main_conf_content = deep_merge($default_config, $noauto, $unmanaged, $additional_config)

  if $use_internal_resolv_conf != undef {
    case $use_internal_resolv_conf {
      'stub': {
        $link_target = '/run/NetworkManager/resolv.conf'
        $link = true
      }
      true: {
        $link_target = '/run/NetworkManager/no-stub-resolv.conf'
        $link = true
      }
      default : {
        $link_target = undef
        $link = false
      }
    }
    if $link {
      file {
        '/etc/resolv.conf':
          ensure => link,
          force  => true,
          target => $link_target;
      }
    }
    else {
      file {
        '/etc/resolv.conf':
          ensure => file,
          force  => true,
          owner  => 'root',
          group  => 'root',
          mode   => '0644';
      }
    }
  }

  networkmanager_keyfile {
    $main_conf_file:
      ensure      => present,
      owner       => 'root',
      group       => 'root',
      mode        => '0600',
      notify      => Class['networkmanager::service'],
      content     => $main_conf_content,
      show_diff   => $networkmanager::show_diff,
      secret_keys => $networkmanager::secret_keys;
  }

  $connections_dir = $networkmanager::connections_dir

  file {
    $connections_dir:
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0600';
  }

  # every file of the directory which is not a keyfile managed by puppet is removed
  networkmanager_keyfile_dir {
    $connections_dir:
      purge => $erase_unmanaged_keyfiles;
  }
}
