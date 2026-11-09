# Reloads the connections and changes the state of the connection through nmcli, after the NetworkManager
# D-Bus service answers. The wait is limited to 60 seconds, the command fails when the service does not appear.
# @param uuid
#   the connection uuid
# @param state
#   the desired connection state
function networkmanager::reload_connection(
  Pattern[/\A\h{8}-(\h{4}-){3}\h{12}\z/] $uuid,
  Enum['up', 'down'] $state,
) >> String {
  $gdbus = '/usr/bin/gdbus introspect --system --dest org.freedesktop.NetworkManager --object-path /org/freedesktop/NetworkManager/Settings'
  $wait = "n=0; until ${gdbus} >/dev/null 2>&1; do n=\$((n + 1)); if test 60 -le \"\${n}\"; then echo 'NetworkManager did not appear on the D-Bus' >&2; exit 1; fi; sleep 1; done"
  "${wait} && /usr/bin/nmcli connection reload && /usr/bin/nmcli connection ${state} ${uuid}"
}
