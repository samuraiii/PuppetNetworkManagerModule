# This defined resource manages the connection keyfiles
# It should not be used by user
#
# @param content
#   The keyfile as a hash of the sections, each section is a hash of the settings (rendered by the networkmanager_keyfile provider)
# @param ensure
#   state of the interface config DEFAULT: present
define networkmanager::connection_keyfile_manage (
  Hash                      $content,
  Enum['absent', 'present'] $ensure = present,

) {
  assert_private()

  if $title !~ Networkmanager::Connection_id {
    fail("The connection title may contain only printable ASCII characters except '/' and '\\' and must not start with a dot")
  }

  networkmanager_keyfile {
    "${networkmanager::connections_dir}/${title}.nmconnection":
      ensure      => $ensure,
      owner       => 'root',
      group       => 'root',
      mode        => '0600',
      content     => $content,
      show_diff   => $networkmanager::show_diff,
      secret_keys => $networkmanager::secret_keys;
  }
}
