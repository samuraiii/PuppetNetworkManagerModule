require 'puppet/parameter/boolean'

# A directory with the NetworkManager keyfiles, whose files which are not managed by the networkmanager_keyfile
# resources of the catalog can be removed. The directory itself is not managed by it (use the file resource).
Puppet::Type.newtype(:networkmanager_keyfile_dir) do
  @doc = <<-DOC
    Removes the *.nmconnection files of the directory which are not managed by a networkmanager_keyfile resource
    of the catalog, when `purge` is true.
  DOC

  newparam(:path, namevar: true) do
    desc 'The absolute path of the directory.'
    validate do |value|
      raise ArgumentError, "The path must be absolute: '#{value}'" unless Puppet::Util.absolute_path?(value)
    end
  end

  newparam(:purge, boolean: true, parent: Puppet::Parameter::Boolean) do
    desc 'Whether to remove the *.nmconnection files which are not managed by the catalog.'
    defaultto false
  end

  # the generated resources remove the files; the paths are compared normalized (a trailing slash of the directory
  # gives a double slash in the path of a keyfile), the directory is listed literally (not as a glob pattern) and
  # only the *.nmconnection files, which are the only ones NetworkManager reads, are removed
  def generate
    return [] unless self[:purge]
    return [] unless ::File.directory?(self[:path])

    managed = catalog.resources.select { |r| :networkmanager_keyfile == r.type }.map { |r| ::File.expand_path(r[:path]) }
    files = Dir.children(self[:path]).grep(%r{\.nmconnection\z}).map { |name| ::File.join(self[:path], name) }
    unmanaged = files.select { |file| ::File.file?(file) }.map { |file| ::File.expand_path(file) } - managed
    unmanaged.sort.map { |file| Puppet::Type.type(:networkmanager_keyfile).new(path: file, ensure: :absent) }
  end

  autorequire(:file) do
    [self[:path]]
  end
end
