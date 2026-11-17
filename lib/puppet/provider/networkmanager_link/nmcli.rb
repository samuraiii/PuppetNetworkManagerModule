# frozen_string_literal: true

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

  # the readers, a failure is an answer (no such device, not running...)
  def run(*command)
    Puppet::Util::Execution.execute(command, failonfail: false, combine: true)
  end

  # the writers, a failure raises Puppet::ExecutionFailure with the command and its output
  def run!(*command)
    Puppet::Util::Execution.execute(command, failonfail: true, combine: true)
  end

  # the device name, found by the MAC address when the interface name is not given
  def device
    return resource[:interface_name] if resource[:interface_name]

    files = Dir.glob('/sys/class/net/*/address').sort.select { |file| resource[:mac_address] == read_address(file) }
    names = files.map { |file| File.basename(File.dirname(file)) }
    raise Puppet::Error, "The MAC address #{resource[:mac_address]} of #{resource[:name]} belongs to more than one device (#{names.join(', ')}), set the interface_name" if names.length > 1

    names.first
  end

  # an interface can vanish between the glob and the read
  def read_address(file)
    File.read(file).strip.downcase
  rescue SystemCallError
    nil
  end

  # NetworkManager 1.57+ lists the option in the help, the distributions backport it into older versions
  def permanent_managed?
    return false if nmcli.nil?

    run(nmcli, 'device', 'set', 'help').include?('--permanent')
  end

  # the device exists in the kernel (the error message of ip about a missing device is not an output of an up link)
  def device_exists?(dev)
    Dir.exist?(File.join('/sys/class/net', dev))
  end

  # the exit status is checked, a failing ip prints its error message to the same output
  def link_up?(dev)
    return false if ip.nil?

    result = run(ip, '-o', 'link', 'show', 'up', 'dev', dev)
    result.exitstatus.zero? && '' != result.strip
  end

  def unmanaged?(dev)
    result = run(nmcli, '-g', 'GENERAL.STATE', 'device', 'show', dev)
    result.exitstatus.zero? && result.downcase.include?('unmanaged')
  end

  # :down (link down, NetworkManager can not unmanage it), :managed, :unmanaged (link up)
  # or :unmanaged_down (both), a device that is down is :managed when NetworkManager can unmanage it but did not.
  # A device which does not exist (no such MAC, a typo, not renamed yet) is :missing, nothing can be done with it and
  # the resource is in sync in both states.
  def state
    dev = device
    return :missing if dev.nil? || !device_exists?(dev)

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
        run!(nmcli, 'device', 'set', dev, 'managed', '--permanent', 'down')
        # the unmanaged device keeps the link as it was, so the link is shut down too
        run!(ip, 'link', 'set', 'dev', dev, 'down') if link_up?(dev)
      else
        raise Puppet::Error, "ip not found, can not set the link of #{dev} down" if ip.nil?

        run!(ip, 'link', 'set', 'dev', dev, 'down')
      end
    elsif permanent_managed?
      run!(nmcli, 'device', 'set', dev, 'managed', '--permanent', 'yes')
    elsif !ip.nil?
      # nothing unmanaged the device, the link which was shut down by the state down is brought up
      run!(ip, 'link', 'set', 'dev', dev, 'up')
    end
  end
end
