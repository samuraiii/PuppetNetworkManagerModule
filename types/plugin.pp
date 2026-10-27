# The name of a NetworkManager plugin (eg. 'keyfile', 'ifcfg-rh'). Matches: a lowercase letter, then lowercase
# letters, digits and dashes
type Networkmanager::Plugin = Pattern[/\A[a-z][a-z0-9-]*\z/]
