# Returns stable connection uuid unless connection $id is uuid already.
# @param id
#   connection id
function networkmanager::connection_uuid(
  String $id,
) >> String {
  if $id =~ /\AUUID=/ {
    fail("The id '${id}' looks like the nmcli UUID= prefix, give the plain UUID (without the prefix) or the id of a connection")
  }
  if $id =~ /\A\h{8}-(\h{4}-){3}\h{12}\z/ {
    $id
  }
  else {
    fqdn_uuid("${networkmanager::sys_id}${id}sPubI8dBBZgpiY9j5OwJpF")
  }
}
