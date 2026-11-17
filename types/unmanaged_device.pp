# A device for the unmanaged-devices of NetworkManager.conf: a MAC address or an interface name, which may be a glob
# (eg. 'docker*'). Matches: 1 to 15 printable ASCII characters except / \ : and ; (the separator of the list)
type Networkmanager::Unmanaged_device = Variant[Stdlib::MAC, Pattern[/\A[!-~&&[^\/\\:;]]{1,15}\z/]]
