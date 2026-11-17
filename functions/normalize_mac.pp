# Returns the MAC address in the form NetworkManager and the DUIDs use: lowercase hex digit pairs separated by colons.
# Only the hex digits of the value are kept (the separator may be a dash), then the colon is put between the pairs.
# @param mac
#   MAC address (6 bytes, or 20 bytes of an InfiniBand device)
function networkmanager::normalize_mac(
  Stdlib::MAC $mac,
) >> String {
  $hex = downcase(regsubst($mac, '[^[:xdigit:]]', '', 'G'))
  regsubst($hex, '(\h{2})(?=.)', '\1:', 'G')
}
