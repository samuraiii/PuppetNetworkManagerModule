# A directory with the NetworkManager keyfiles, whose files which are not managed by the networkmanager_keyfile
# resources of the catalog can be removed. The directory itself is not managed by it (use the file resource).
Puppet::Type.newtype(:networkmanager_keyfile_dir) do
  @doc = <<-DOC
    Removes the files of the directory which are not managed by a networkmanager_keyfile resource of the catalog,
    when `purge` is true.
  DOC

  newparam(:path, namevar: true) do
    desc 'The absolute path of the directory.'
    validate do |value|
      raise ArgumentError, "The path must be absolute: '#{value}'" unless Puppet::Util.absolute_path?(value)
    end
  end

  newparam(:purge, boolean: true, parent: Puppet::Parameter::Boolean) do
    desc 'Whether to remove the files which are not managed by the catalog.'
    defaultto false
  end

  # the generated resources remove the files
  def generate
    return [] unless self[:purge]

    managed = catalog.resources.select { |r| :networkmanager_keyfile == r.type }.map { |r| r[:path] }
    unmanaged = Dir.glob(::File.join(self[:path], '*')).select { |file| ::File.file?(file) } - managed
    unmanaged.sort.map { |file| Puppet::Type.type(:networkmanager_keyfile).new(path: file, ensure: :absent) }
  end

  autorequire(:file) do
    [self[:path]]
  end
end
