# This defined resource manages one connection: it checks the id, writes the keyfile, activates (or deactivates, or
# removes) the connection, keeps the link of its device in the state of the connection and collects the activation
# execs. It is the common part of all the networkmanager::ifc::* defined resources, which only build the content
# of the keyfile. The title is the id of the connection.
# It should not be used by user
#
# @param content
#   The keyfile as a hash of the sections, it has to hold the `connection.uuid`, which is used to activate the connection
# @param ensure
#   state of the interface config DEFAULT: present
# @param state
#   state of the interface (UP/DOWN) not relevant when $ensure == 'absent' DEFAULT: 'up'
# @param after
#   UUIDs of the connections (master, parent) which are activated before this one when they are managed by this module
# @param interface_name
#   name of the device of the connection, the link of the device is kept in the state of the connection (with the $mac_address)
# @param mac_address
#   MAC address of the device of the connection
define networkmanager::connection_manage (
  Hash                                     $content,
  Enum['absent', 'present']                $ensure = present,
  Enum['up', 'down']                       $state = 'up',
  Array[Pattern[/\A\h{8}-(\h{4}-){3}\h{12}\z/]] $after = [],
  Optional[Networkmanager::Interface_name] $interface_name = undef,
  Optional[Stdlib::MAC]                    $mac_address = undef,
) {
  assert_private()

  include networkmanager
  Class['networkmanager'] -> Networkmanager::Connection_manage[$title]

  if $title !~ String[3, $networkmanager::max_length_of_connection_id] {
    fail("The connection \$id must have length from 3 to ${networkmanager::max_length_of_connection_id} characters")
  }
  if $title !~ Networkmanager::Connection_id {
    fail("The connection \$id may contain only printable ASCII characters except '/' and '\\' and must not start with a dot")
  }

  # the connection is activated by its uuid
  $uuid = $content['connection']['uuid']
  if $uuid !~ Pattern[/\A\h{8}-(\h{4}-){3}\h{12}\z/] {
    fail("The 'connection.uuid' for connection '${title}' must be an UUID")
  }

  networkmanager::connection_keyfile_manage {
    $title:
      ensure  => $ensure,
      content => $content;
  }

  networkmanager::activate_connection($uuid, $title, $state, $ensure, $after)

  # a removed connection gives its device back to NetworkManager (a device unmanaged by the state 'down' would stay so)
  if $interface_name or $mac_address {
    networkmanager::connection_link {
      $uuid:
        ensure         => $ensure,
        state          => $state,
        interface_name => $interface_name,
        mac_address    => $mac_address;
    }
  }

  include networkmanager::reload
}
