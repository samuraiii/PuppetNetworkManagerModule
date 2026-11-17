# Fails when an address of the semicolon separated string is not a valid IPv6 address (with the prefix length when $cidr is true).
# The arrays are validated by their data types, the legacy string format only has a rough pattern.
# @param addresses
#   the address string or array, undef is accepted
# @param cidr
#   whether the prefix length is required (the addresses) or forbidden (the DNS servers)
# @param label
#   the name of the parameter (for the error message)
function networkmanager::check_ipv6_list(
  Optional[Variant[String, Array[String]]] $addresses,
  Boolean                                  $cidr,
  String                                   $label,
) >> Undef {
  if $addresses =~ String {
    $addresses.split(';').filter |$address| { '' != $address }.each |$address| {
      $valid = $cidr ? {
        true    => $address =~ Stdlib::IP::Address::V6::CIDR,
        default => $address =~ Stdlib::IP::Address::V6::Nosubnet,
      }
      unless $valid {
        fail("The ${label} contains '${address}' which is not a valid IPv6 address")
      }
    }
  }
  undef
}
