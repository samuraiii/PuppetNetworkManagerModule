# Validates that the connection has at least one of 'mac address' or 'interface name' supplied. A connection which is
# removed (ensure absent) needs neither, the ones which are supplied are still validated by their data types.
# @param caller
#   the puppet name of the resource which called this function (for sensible error line)
# @param caller_title
#   the instance of the resource which called the function (for sensible error line)
# @param interface_mac
#   the connection interface mac address
# @param interface_name
#   the connection interface name
# @param type
#   the type of the connection (the section of the MAC address depends on it)
# @param ensure
#   present or absent, the connection which is absent needs no interface name and no mac address
function networkmanager::validate_ifc_name_and_mac (
  String                                   $caller,
  String                                   $caller_title,
  Optional[Stdlib::MAC]                    $interface_mac,
  Optional[Networkmanager::Interface_name] $interface_name,
  String                                   $type = 'ethernet',
  Enum['absent', 'present']                $ensure = 'present',
) >> Hash {
  if 'present' == $ensure and !($interface_mac or $interface_name) {
    fail("You need to provide either mac address or interface name for ${caller}(${$caller_title})")
  }

  networkmanager::compact_keyfile({
    'connection' => { 'interface-name' => $interface_name },
  }) + networkmanager::mac_address_settings($type, $interface_mac)
}
