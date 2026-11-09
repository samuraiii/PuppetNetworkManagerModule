# Returns IPv6 DHCP DUID
# @param mac
#   MAC address of the interface
# Additional variables:
#   $networkmanager::duid_prefix = prefix for the dhcp duid (taken from the networkmanager class)
function networkmanager::connection_duid(
  Stdlib::MAC $mac,
) >> String {
  "${networkmanager::duid_prefix_d}:${networkmanager::normalize_mac($mac)}"
}
