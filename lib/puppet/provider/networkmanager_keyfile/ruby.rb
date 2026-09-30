require 'digest'
require 'etc'
require 'tempfile'
require 'puppet/util'
require 'puppet/util/diff'
require 'puppet/util/execution'

Puppet::Type.type(:networkmanager_keyfile).provide(:ruby) do
  desc 'Renders the keyfile (GLib key file format) from the hash of sections and writes it.'

  # the default directory of the connections, listed by `puppet resource`
  # (the directory of the module is the $networkmanager::connections_dir, the purge is done by the
  # networkmanager_keyfile_dir type)
  def self.connections_dir
    '/etc/NetworkManager/system-connections'
  end

  # the keys and the sections whose values are censored in the diffs
  def self.secret_key
    %r{password|passphrase|secret|private-key|preshared-key|token|\A(?:psk|pin|wep-key[0-3]|mka-c[ak]n?k?)\z}i
  end

  def self.secret_sections
    %w[vpn-secrets secrets]
  end

  def self.censored
    '<redacted>'
  end

  # the files of the connections in the default directory
  def self.instances
    Dir.glob(File.join(connections_dir, '*')).select { |file| File.file?(file) }.sort.map { |file| new(name: file) }
  end

  # whether the installed NetworkManager (1.20+) accepts the `disabled` IPv6 method: an invalid value makes nmcli fail
  # before anything is created and list the valid ones. Unknown (no nmcli, an unknown output) is taken as supported.
  def self.ipv6_disabled_supported?
    return @ipv6_disabled_supported if defined?(@ipv6_disabled_supported)

    nmcli = Puppet::Util.which('nmcli')
    command = [nmcli, 'connection', 'add', 'type', 'ethernet', 'ipv6.method', 'probe']
    output = nmcli.nil? ? '' : Puppet::Util::Execution.execute(command, failonfail: false, combine: true).to_s
    list = output.match(%r{not among \[([^\]]*)\]})
    @ipv6_disabled_supported = list.nil? || list[1].split(%r{,\s*}).include?('disabled')
  end

  def path
    resource[:path]
  end

  def exists?
    File.file?(path)
  end

  def create
    write(resource[:content] || {})
    self.mode = resource[:mode] if resource[:mode]
    self.owner = resource[:owner] if resource[:owner]
    self.group = resource[:group] if resource[:group]
  end

  def destroy
    File.delete(path)
  end

  # ----- content

  def checksum
    exists? ? "{sha256}#{Digest::SHA256.file(path).hexdigest}" : :absent
  end

  def checksum_of(sections)
    "{sha256}#{Digest::SHA256.hexdigest(render(sections))}"
  end

  def content=(sections)
    write(sections)
  end

  def write(sections)
    text = render(sections)
    Puppet::Util.replace_file(path, 0o600) { |file| file.write(text) }
  end

  # the diff of the file on the disk and the new content, both with the secrets censored
  def diff(sections)
    return '' unless exists?
    return '' if Puppet[:diff].to_s.empty?

    old = Tempfile.new('nm-keyfile-old')
    new = Tempfile.new('nm-keyfile-new')
    begin
      old.write(censor(File.read(path)))
      new.write(censor(render(sections)))
      [old, new].each(&:flush)
      text = Puppet::Util::Diff.diff(old.path, new.path).to_s
      text.empty? ? '(only the values of the censored secrets differ)' : text
    ensure
      [old, new].each(&:close!)
    end
  end

  def secret_key?(section, key)
    self.class.secret_sections.include?(section) || self.class.secret_key.match?(key) ||
      Array(resource[:secret_keys]).include?(key)
  end

  # replaces the values of the secret settings of a rendered keyfile
  def censor(text)
    section = nil
    text.each_line.map do |line|
      if (header = line.match(%r{\A\[(.*)\]\s*\z}))
        section = header[1]
        line
      elsif (setting = line.match(%r{\A([^#=\s][^=]*)=(.*)\z}m)) && secret_key?(section, setting[1].strip)
        "#{setting[1]}=#{self.class.censored}\n"
      else
        line
      end
    end.join
  end

  # ----- rendering

  def render(sections)
    body = adjust(sections).map do |section, settings|
      lines = settings.map { |key, value| "#{key}=#{ini_value(value)}\n" }.join
      "[#{section}]\n#{lines}\n"
    end
    "#{resource[:header]}\n\n#{body.join}"
  end

  # NetworkManager older than 1.20 does not know the `disabled` IPv6 method
  def adjust(sections)
    ipv6 = sections['ipv6']
    return sections unless ipv6.is_a?(Hash) && 'disabled' == ipv6['method'] && !self.class.ipv6_disabled_supported?

    unless @warned
      Puppet.warning("#{path}: the \"disabled\" IPv6 method is not available in NetworkManager older than 1.20, " \
                     'changing to "ignore"')
      @warned = true
    end
    sections.merge('ipv6' => ipv6.merge('method' => 'ignore'))
  end

  # formats a value for the GLib key file: not quoted, the backslash, the new line, the tab, the carriage return and
  # the leading or trailing space escaped, an array is written as the list of values terminated by a semicolon (a;b;)
  def ini_value(value)
    case value
    when nil
      ''
    when Array
      items = value.map { |item| escape(item.to_s).gsub(';') { '\;' } }
      items.empty? ? '' : "#{items.join(';')};"
    when Hash
      raise Puppet::Error, "#{path}: a hash can not be a value of a keyfile setting"
    else
      escape(value.to_s)
    end
  end

  def escape(string)
    string.gsub('\\') { '\\\\' }.gsub("\n") { '\\n' }.gsub("\t") { '\\t' }.gsub("\r") { '\\r' }
          .sub(%r{\A }) { '\\s' }.sub(%r{ \z}) { '\\s' }
  end

  # ----- the file attributes

  def mode
    exists? ? format('%04o', File.stat(path).mode & 0o7777) : :absent
  end

  def mode=(value)
    File.chmod(value.to_i(8), path)
  end

  def owner
    return :absent unless exists?

    uid = File.stat(path).uid
    Etc.getpwuid(uid).name
  rescue ArgumentError
    uid.to_s
  end

  def owner=(name)
    File.chown(Etc.getpwnam(name).uid, nil, path)
  end

  def group
    return :absent unless exists?

    gid = File.stat(path).gid
    Etc.getgrgid(gid).name
  rescue ArgumentError
    gid.to_s
  end

  def group=(name)
    File.chown(nil, Etc.getgrnam(name).gid, path)
  end
end
