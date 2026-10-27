# Name of a network device. Matches: not 'all' or 'default' (the sysctl directories of the interfaces), a letter or a
# digit first (a dash would be taken as an option by ip and nmcli), then 0 to 14 printable ASCII characters except
# the space, / \ : and the glob characters * ? [ ] (1 to 15 characters in total, as the kernel allows)
type Networkmanager::Interface_name = Pattern[/\A(?!(all|default)\z)[0-9A-Za-z][!-~&&[^\/\\:*?\[\]]]{0,14}\z/]
