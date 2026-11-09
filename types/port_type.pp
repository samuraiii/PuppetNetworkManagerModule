# The type of the controller of a connection which is its port (the slave-type of the keyfile): the values NetworkManager accepts
# for the connection.slave-type (the alias of connection.port-type)
type Networkmanager::Port_type = Enum['bond', 'bridge', 'ovs-bridge', 'ovs-port', 'team', 'vrf']
