# Fails when the additional_config of a connection replaces a connection setting which the module computes and relies
# on: the uuid (the connection is activated by the generated one), the id (the name of the keyfile), the interface-name
# (set by the interface_name parameter), the master and the slave-type (set by the master and slave_type parameters,
# the module orders the activation by them).
# @param additional_config
#   the additional_config of the connection
# @param id
#   the id of the connection (for the error message)
function networkmanager::forbid_uuid_override(
  Hash   $additional_config,
  String $id,
) >> Undef {
  $connection = $additional_config['connection']
  if $connection =~ Hash {
    ['uuid', 'id', 'interface-name', 'master', 'slave-type'].each |$key| {
      if $key in $connection {
        fail("The additional_config of the connection '${id}' can not set the connection.${key}, it is set by the module (use the parameters of the define)")
      }
    }
  }
  undef
}
