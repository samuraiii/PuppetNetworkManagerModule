# frozen_string_literal: true

require 'json'
require_relative '../lib/puppet/type/networkmanager_keyfile'
require_relative '../lib/puppet/provider/networkmanager_keyfile/ruby'

# the tests do not ask the installed nmcli whether the `disabled` IPv6 method is supported
Puppet::Type.type(:networkmanager_keyfile).provider(:ruby).instance_variable_set(:@ipv6_disabled_supported, true)

# Facts are generated from operatingsystem_support in metadata.json instead of
# facterdb, so every supported OS release is tested regardless of which
# releases the installed facterdb version happens to know.
NM_OS_FAMILY = {
  'Archlinux' => 'Archlinux',
  'Debian' => 'Debian',
  'Gentoo' => 'Gentoo',
  'Manjaro' => 'Archlinux',
  'Ubuntu' => 'Debian',
}.tap { |h| h.default = 'RedHat' }.freeze

# Builds a facts hash for the given OS.
def nm_test_facts(name, release, family = NM_OS_FAMILY[name])
  {
    'kernel' => 'Linux',
    'os' => {
      'family' => family,
      'name' => name,
      'release' => { 'major' => release, 'full' => release },
    },
    'networking' => { 'hostname' => 'testhost', 'fqdn' => 'testhost.example.com' },
  }
end

# Yields a label and the facts hash for every OS release listed in metadata.json.
def each_test_os
  metadata = JSON.parse(File.read(File.expand_path('../metadata.json', __dir__)))
  metadata['operatingsystem_support'].each do |entry|
    # rolling release systems have no release listed in metadata.json
    entry.fetch('operatingsystemrelease', ['rolling']).each do |release|
      yield "#{entry['operatingsystem']} #{release}", nm_test_facts(entry['operatingsystem'], release)
    end
  end
end

# The text of a networkmanager_keyfile of the catalogue, rendered by its provider.
def keyfile_text(path)
  content = catalogue.resource('Networkmanager_keyfile', path)[:content]
  Puppet::Type.type(:networkmanager_keyfile).new(path: path, content: content).provider.render(content)
end
