# frozen_string_literal: true

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
      raise ArgumentError, "Invalid interface name '#{value}'" unless value =~ %r{\A(?!(all|default)\z)[0-9A-Za-z][!-~&&[^/\\:*?\[\]]]{0,14}\z}
    end
  end

  newparam(:mac_address) do
    desc 'The MAC address of the network device (6 bytes, or 20 bytes of an InfiniBand device, the separator is a colon or a dash), used when the `interface_name` is not set.'
    munge { |value| value.downcase.tr('-', ':') }
    validate do |value|
      raise ArgumentError, "Invalid MAC address '#{value}'" unless value =~ %r{\A\h\h([:-]\h\h){5}\z|\A\h\h([:-]\h\h){19}\z}
    end
  end

  newproperty(:state) do
    desc <<-DOC
      `down`: the link is down (with NetworkManager supporting it also unmanaged, persistently).
      `managed`: the device is not unmanaged by a previous `down`, and a link which the `down` shut down with `ip`
      (NetworkManager without the permanent unmanage) is brought up. A device that does not exist is in sync in both states.
    DOC
    newvalues(:down, :managed)

    def retrieve
      provider.state
    end

    def insync?(is)
      # :missing (no such device) is in sync, there is nothing to do with it
      if :down == should
        %i[down unmanaged_down missing].include?(is)
      else
        # :down is the link shut down where NetworkManager can not unmanage the device, it is brought up
        %i[managed missing].include?(is)
      end
    end
  end

  validate do
    raise ArgumentError, 'Either interface_name or mac_address is required' if self[:interface_name].nil? && self[:mac_address].nil?
  end
end
