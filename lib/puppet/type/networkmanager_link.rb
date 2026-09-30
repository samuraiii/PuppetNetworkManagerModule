# Keeps the link of a network device down (or lets NetworkManager manage it again).
# The way of doing it is chosen when the resource is applied, not when the catalog is compiled or facts are collected,
# because NetworkManager may be installed by the very same run: NetworkManager 1.57+ (and the distributions that
# backport it) supports `nmcli device set <ifc> managed --permanent down`, the older ones only `ip link set <ifc> down`.
Puppet::Type.newtype(:networkmanager_link) do
  @doc = <<-DOC
    Sets the link of the device down persistently (the device is unmanaged by NetworkManager if it can do it),
    or makes the device managed by NetworkManager again after it was unmanaged by `down`.
  DOC

  newparam(:name, namevar: true) do
    desc 'An arbitrary name of the resource.'
  end

  newparam(:interface_name) do
    desc 'The name of the network device. Either this or `mac_address` is required.'
    validate do |value|
      raise ArgumentError, "Invalid interface name '#{value}'" unless value =~ %r{\A[^\s/:]{1,15}\z}
    end
  end

  newparam(:mac_address) do
    desc 'The MAC address of the network device, used when the `interface_name` is not set.'
    munge(&:downcase)
    validate do |value|
      raise ArgumentError, "Invalid MAC address '#{value}'" unless value =~ %r{\A\h\h(:\h\h){5}\z}
    end
  end

  newproperty(:state) do
    desc <<-DOC
      `down`: the link is down (with NetworkManager supporting it also unmanaged, persistently).
      `managed`: the device is not unmanaged by a previous `down` (the link is not touched, it is brought up by the connection).
    DOC
    newvalues(:down, :managed)

    def retrieve
      provider.state
    end

    def insync?(is)
      if :down == should
        [:down, :unmanaged_down].include?(is)
      else
        ![:unmanaged, :unmanaged_down].include?(is)
      end
    end
  end

  validate do
    if self[:interface_name].nil? && self[:mac_address].nil?
      raise ArgumentError, 'Either interface_name or mac_address is required'
    end
  end
end
