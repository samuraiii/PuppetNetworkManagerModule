# This class is used to collect the virtual keyfile activation execs of the catalog and apply them.
# Not to be used by user

class networkmanager::reload {
  assert_private()

  Exec <| tag == $networkmanager::activation_tag |>
}
