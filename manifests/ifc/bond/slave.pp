# This defined resource creates bond slave keyfile.
#
# @param master
#   $id or UUID of the master interface under which this slave should operate REQUIRED
# @param ensure
#   state of the interface config DEFAULT: present
# @param state
#   state of the interface (UP/DOWN) not relevant when $ensure == 'absent' DEFAULT: 'up'
# @param id
#   the name of the connection DEFAULT: $title of the resource
# @param type
#   connection type DEFAULT: ethernet
# @param mac_address
#   the mac of the interface for the connection REQUIRED IF $interface_name was not supplied
# @param interface_name
#   name of the connection interface REQUIRED IF $mac_address was not supplied
# @param additional_config
#   Other not covered configuration
#   In the case when you want to specify special not listed parameters you can add them through
#   $additional_config hash and it will be merged with other parameters.
#   The additional_config has the HIGHEST priority when merged!
#   ie: it will override the defined values of the connection in case of the conflict
#   A setting with an empty string value ('') is not written, like an unset one; the connection.id, uuid, interface-name, master and slave-type can not be overridden
define networkmanager::ifc::bond::slave (
  String                    $master,
  Enum['absent', 'present'] $ensure = present,
  Enum['up', 'down']        $state = 'up',
  String                    $id = $title,
  String                    $type = 'ethernet',
  Optional[Stdlib::MAC]     $mac_address = undef,
  Optional[Networkmanager::Interface_name] $interface_name = undef,
  Hash                      $additional_config = {},
) {
  include networkmanager


  $uuid = networkmanager::connection_uuid($id)

  $int_mac_config = networkmanager::validate_ifc_name_and_mac(
    $name,
    $title,
    $mac_address,
    $interface_name,
    $type
  )
  networkmanager::forbid_uuid_override($additional_config, $id)

  $master_uuid = networkmanager::connection_uuid($master)

  $connection_config = {
    connection => {
      id         => $id,
      uuid       => $uuid,
      type       => $type,
      master     => $master_uuid,
      slave-type => 'bond',
    },
  }

  $after = [$master_uuid]

  $keyfile_contents = deep_merge($int_mac_config, $connection_config, $additional_config)

  networkmanager::connection_manage {
    $id:
      ensure         => $ensure,
      state          => $state,
      content        => $keyfile_contents,
      after          => $after,
      interface_name => $interface_name,
      mac_address    => $mac_address;
  }
}
