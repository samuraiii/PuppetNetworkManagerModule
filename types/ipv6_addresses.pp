# One or more IPv6 addresses with the prefix length (eg. '2001:db8::5/64'),
# as an array or as a string with the addresses separated by a semicolon (eg. '2001:db8::5/64;2001:db8:1::5/64').
# The string has only a rough pattern here (hex digits, colons, dots and the prefix length 0 to 128), every
# address of it is validated by networkmanager::check_ipv6_list.
type Networkmanager::IPV6_ADDRESSES = Variant[
  Stdlib::IP::Address::V6::CIDR,
  Array[Stdlib::IP::Address::V6::CIDR, 1],
  Pattern[/\A[[:xdigit:]:.]+\/(?:[0-9]|[1-9][0-9]|1[01][0-9]|12[0-8])(;[[:xdigit:]:.]+\/(?:[0-9]|[1-9][0-9]|1[01][0-9]|12[0-8]))*;?\z/],
]
