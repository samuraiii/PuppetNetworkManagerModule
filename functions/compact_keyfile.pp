# Removes the undefined settings and the empty sections from a keyfile hash, so the caller
# can list every optional setting in one literal instead of building it up conditionally.
# @param sections
#   hash of sections, each one a hash of settings (undef values are dropped)
function networkmanager::compact_keyfile(
  Hash[String, Hash] $sections,
) >> Hash {
  $compacted = $sections.map |$section, $settings| {
    [$section, $settings.filter |$key, $value| { undef != $value }]
  }
  Hash($compacted.filter |$pair| { !empty($pair[1]) })
}
