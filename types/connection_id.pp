# The id of a connection, which is also used as the name of its keyfile, so it can not escape from the connections
# directory or name a hidden file. Matches: not a dot first, then 1 or more printable ASCII characters (the space
# included) except / and \
type Networkmanager::Connection_id = Pattern[/\A(?!\.)[ -~&&[^\/\\]]+\z/]
