# Returns the connection settings of a connection which is a port of a controller (the master): the UUID of the master
# and the slave-type. NetworkManager refuses a master without the type of the controller, so the slave_type is
# required when the master is set. Returns no settings without the master (the slave_type is ignored then).
# @param master
#   $id or UUID of the controller connection, undef when the connection is not a port
# @param slave_type
#   the type of the controller (bond, bridge, ...)
# @param id
#   the id of the connection (for the error message and to refuse a master which is the connection itself)
function networkmanager::port_settings(
  Optional[String]                    $master,
  Optional[Networkmanager::Port_type] $slave_type,
  String                              $id,
) >> Hash {
  if undef == $master {
    $settings = {}
  }
  elsif undef == $slave_type {
    fail("The connection '${id}' has the master '${master}' but no slave_type: NetworkManager refuses a master without the type of the controller (bond, bridge, team, ovs-port, vrf, ...), set the slave_type")
  }
  elsif networkmanager::connection_uuid($master) == networkmanager::connection_uuid($id) {
    fail("The master '${master}' of the connection '${id}' is the connection itself")
  }
  else {
    $settings = { 'master' => networkmanager::connection_uuid($master), 'slave-type' => $slave_type }
  }
  $settings
}
