# Up to 5 IPv6 DNS server addresses, either as an array of addresses (eg. ['2001:db8::53', 'fd00::1'])
# or as the keyfile string with the addresses (full or compressed form) separated by a semicolon (eg. '2001:db8::53;fd00::1;').
# The string has only a rough pattern here, every address of it is validated by networkmanager::check_ipv6_list.
type Networkmanager::DNS_IPV6 = Variant[
  Pattern[/\A[[:xdigit:]:.]+(;[[:xdigit:]:.]+){0,4};?\z/],
  Array[Stdlib::IP::Address::V6::Nosubnet, 1, 5],
]
