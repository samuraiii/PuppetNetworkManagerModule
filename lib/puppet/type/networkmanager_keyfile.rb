require 'puppet/util/diff'

# A NetworkManager keyfile (a connection or the NetworkManager.conf), written from a hash of sections.
# The file is rendered by the provider when the catalog is applied, so the rendering can use what is known only then
# (eg. the NetworkManager which is installed by the same run does not support the `disabled` IPv6 method before 1.20).
# The content of the file is never printed, the diffs (if enabled) have the secrets (passwords, keys, ...) censored.
Puppet::Type.newtype(:networkmanager_keyfile) do
  @doc = <<-DOC
    Manages a keyfile of the NetworkManager from a hash of sections, each section is a hash of settings
    (a string, a number, a boolean or an array, which is written as `a;b;`).
    The `puppet resource` shows just the checksum of the content, the diffs shown by the changes have the secrets censored.
  DOC

  ensurable

  newparam(:path, namevar: true) do
    desc 'The absolute path of the keyfile.'
    validate do |value|
      raise ArgumentError, "The path must be absolute: '#{value}'" unless Puppet::Util.absolute_path?(value)
    end
  end

  newparam(:header) do
    desc 'The comment written on the top of the file.'
    defaultto '# THIS FILE IS CONTROLLED BY PUPPET'
  end

  newparam(:show_diff, boolean: true, parent: Puppet::Parameter::Boolean) do
    desc <<-DOC
      Whether to show the diff of the file when it changes (with the secrets censored). The diff is shown
      only when the `show_diff` setting of Puppet is enabled as well (as it is for the file resource).
    DOC
    defaultto true
  end

  newparam(:secret_keys, array_matching: :all) do
    desc <<-DOC
      The names of the settings whose values are censored in the diffs, in addition to the built in ones: the keys with
      `password`, `passphrase`, `secret`, `private-key`, `preshared-key` or `token` in the name, `psk`, `pin`,
      `wep-key0` - `wep-key3`, `mka-cak`, `mka-ckn` and everything in the `vpn-secrets` and `secrets` sections.
    DOC
    defaultto []
  end

  newproperty(:content) do
    desc 'The sections of the keyfile as a hash of hashes.'

    validate do |value|
      raise ArgumentError, 'The content must be a hash of sections' unless value.is_a?(Hash)
      raise ArgumentError, 'Each section of the content must be a hash of settings' unless value.values.all?(Hash)
    end

    # only the checksum leaves the provider, the content can hold the secrets
    def retrieve
      provider.checksum
    end

    # the diff is made here, before the file is written (the messages of the change are made after it)
    def insync?(is)
      insync = is == provider.checksum_of(should)
      @diff_text = insync ? '' : diff_text(should)
      insync
    end

    def is_to_s(value) # rubocop:disable Naming/PredicatePrefix
      "'#{value}'"
    end

    def should_to_s(value)
      "'#{provider.checksum_of(value)}'#{@diff_text}"
    end

    def change_to_s(current, desired)
      "content changed '#{current}' to '#{provider.checksum_of(desired)}'#{@diff_text}"
    end

    def diff_text(sections)
      return '' unless Puppet[:show_diff] && resource[:show_diff]

      text = provider.diff(sections)
      text.empty? ? '' : "\n#{text}"
    end
  end

  newproperty(:mode) do
    desc 'The octal mode of the file.'
    defaultto '0600'
    munge { |value| format('%04o', value.to_s.to_i(8)) }
    validate do |value|
      raise ArgumentError, "Invalid mode '#{value}'" unless value.to_s =~ %r{\A[0-7]{3,4}\z}
    end
  end

  newproperty(:owner) do
    desc 'The name of the owner of the file.'
    defaultto 'root'
  end

  newproperty(:group) do
    desc 'The name of the group of the file.'
    defaultto 'root'
  end

  autorequire(:file) do
    [::File.dirname(self[:path])]
  end
end
