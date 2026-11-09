# Returns the keyfile settings with the MAC address of the device, in the section which belongs to the type of the connection.
# The MAC address of a connection type which has no section known to the module is refused, put it
# into the additional_config of the connection instead.
# @param type
#   the type of the connection (ethernet, wifi, ...)
# @param mac_address
#   the MAC address (written as aa:bb:cc:dd:ee:ff), undef returns no settings
function networkmanager::mac_address_settings(
  String                $type,
  Optional[Stdlib::MAC] $mac_address,
) >> Hash {
  if undef == $mac_address {
    $result = {}
    $result
  }
  else {
    $section = $type ? {
      /\A(ethernet|802-3-ethernet)\z/ => 'ethernet',
      /\A(wifi|802-11-wireless)\z/    => '802-11-wireless',
      default                         => undef,
    }
    if undef == $section {
      fail("The mac_address can not be set for the connection type '${type}', set the mac-address in the section of the type with the additional_config")
    }
    $settings = { $section => { 'mac-address' => networkmanager::normalize_mac($mac_address) } }
    $settings
  }
}
