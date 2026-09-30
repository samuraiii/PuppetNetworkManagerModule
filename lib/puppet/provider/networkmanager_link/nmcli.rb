require 'puppet/util'
require 'puppet/util/execution'

Puppet::Type.type(:networkmanager_link).provide(:nmcli) do
  desc 'Uses `nmcli device set <ifc> managed --permanent` when NetworkManager supports it, `ip link` otherwise.'

  # nmcli and ip are looked up when they are used, NetworkManager may get installed in the same run
  def nmcli
    Puppet::Util.which('nmcli')
  end

  def ip
    Puppet::Util.which('ip')
  end

  def run(*command)
    Puppet::Util::Execution.execute(command, failonfail: false, combine: true)
  end

  # the device name, found by the MAC address when the interface name is not given
  def device
    return resource[:interface_name] if resource[:interface_name]

    path = Dir.glob('/sys/class/net/*/address').find do |file|
      resource[:mac_address] == File.read(file).strip.downcase
    end
    path.nil? ? nil : File.basename(File.dirname(path))
  end

  # NetworkManager 1.57+ lists the option in the help, the distributions backport it into older versions
  def permanent_managed?
    return false if nmcli.nil?

    run(nmcli, 'device', 'set', 'help').include?('--permanent')
  end

  def link_up?(dev)
    return false if ip.nil?

    run(ip, '-o', 'link', 'show', 'up', 'dev', dev).strip != ''
  end

  def unmanaged?(dev)
    run(nmcli, '-g', 'GENERAL.STATE', 'device', 'show', dev).downcase.include?('unmanaged')
  end

  # :down (link down, NetworkManager can not unmanage it), :managed, :unmanaged (link up)
  # or :unmanaged_down (both), a device that is down is :managed when NetworkManager can unmanage it but did not
  def state
    dev = device
    return :down if dev.nil?

    up = link_up?(dev)
    return (up ? :managed : :down) unless permanent_managed?

    if unmanaged?(dev)
      up ? :unmanaged : :unmanaged_down
    else
      :managed
    end
  end

  def state=(value)
    dev = device
    raise Puppet::Error, "Network device of #{resource[:name]} not found" if dev.nil?

    if :down == value
      if permanent_managed?
        run(nmcli, 'device', 'set', dev, 'managed', '--permanent', 'down')
      else
        run(ip, 'link', 'set', 'dev', dev, 'down')
      end
    elsif permanent_managed?
      run(nmcli, 'device', 'set', dev, 'managed', '--permanent', 'yes')
    end
  end
end
