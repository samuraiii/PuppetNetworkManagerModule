# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:networkmanager_link).provider(:nmcli) do
  let(:resource) { Puppet::Type.type(:networkmanager_link).new(name: 'link', interface_name: 'eno1', state: 'down') }
  let(:provider) { resource.provider }
  let(:execution) { Puppet::Util::Execution }

  before do
    allow(Puppet::Util).to receive(:which).with('nmcli').and_return('/usr/bin/nmcli')
    allow(Puppet::Util).to receive(:which).with('ip').and_return('/usr/sbin/ip')
  end

  def output(text, status = 0)
    Puppet::Util::Execution::ProcessOutput.new(text, status)
  end

  def stub_nmcli(permanent:)
    help = permanent ? "usage: nmcli device set <ifname> managed [--permanent] yes|no\n" : "usage: nmcli device set <ifname> managed yes|no\n"
    allow(execution).to receive(:execute).with(['/usr/bin/nmcli', 'device', 'set', 'help'], anything).and_return(output(help))
  end

  describe '#state=' do
    context 'when NetworkManager can unmanage the device permanently' do
      before { stub_nmcli(permanent: true) }

      it 'unmanages the device and shuts the link down too when it is still up' do
        allow(execution).to receive(:execute).with(['/usr/sbin/ip', '-o', 'link', 'show', 'up', 'dev', 'eno1'], anything)
                                             .and_return(output("2: eno1: <UP>\n"))
        expect(execution).to receive(:execute).with(['/usr/bin/nmcli', 'device', 'set', 'eno1', 'managed', '--permanent', 'down'], hash_including(failonfail: true))
        expect(execution).to receive(:execute).with(['/usr/sbin/ip', 'link', 'set', 'dev', 'eno1', 'down'], hash_including(failonfail: true))
        provider.state = :down
      end

      it 'leaves the link alone when the unmanage already shut it down' do
        allow(execution).to receive(:execute).with(['/usr/sbin/ip', '-o', 'link', 'show', 'up', 'dev', 'eno1'], anything).and_return(output(''))
        allow(execution).to receive(:execute).with(['/usr/bin/nmcli', 'device', 'set', 'eno1', 'managed', '--permanent', 'down'], anything)
        expect(execution).not_to receive(:execute).with(['/usr/sbin/ip', 'link', 'set', 'dev', 'eno1', 'down'], anything)
        provider.state = :down
      end

      it 'raises when the command fails' do
        allow(execution).to receive(:execute).with(['/usr/sbin/ip', '-o', 'link', 'show', 'up', 'dev', 'eno1'], anything).and_return(output(''))
        allow(execution).to receive(:execute)
          .with(['/usr/bin/nmcli', 'device', 'set', 'eno1', 'managed', '--permanent',
                 'down'], hash_including(failonfail: true))
          .and_raise(Puppet::ExecutionFailure, 'nmcli failed')
        expect { provider.state = :down }.to raise_error(Puppet::ExecutionFailure, %r{nmcli failed})
      end

      it 'makes the device managed again' do
        expect(execution).to receive(:execute)
          .with(['/usr/bin/nmcli', 'device', 'set', 'eno1', 'managed', '--permanent',
                 'yes'], hash_including(failonfail: true))
        provider.state = :managed
      end
    end

    context 'when NetworkManager can not unmanage the device permanently' do
      before { stub_nmcli(permanent: false) }

      it 'sets the link down with ip' do
        expect(execution).to receive(:execute).with(['/usr/sbin/ip', 'link', 'set', 'dev', 'eno1', 'down'],
                                                    hash_including(failonfail: true))
        provider.state = :down
      end

      it 'brings the link up which the state down shut down' do
        expect(execution).to receive(:execute).with(['/usr/sbin/ip', 'link', 'set', 'dev', 'eno1', 'up'], hash_including(failonfail: true))
        provider.state = :managed
      end

      it 'has nothing to bring up without ip' do
        allow(Puppet::Util).to receive(:which).with('ip').and_return(nil)
        expect(execution).not_to receive(:execute).with(array_including('up'), anything)
        provider.state = :managed
      end

      it 'fails without ip' do
        allow(Puppet::Util).to receive(:which).with('ip').and_return(nil)
        expect { provider.state = :down }.to raise_error(Puppet::Error, %r{ip not found})
      end
    end

    it 'fails for a device which does not exist' do
      resource = Puppet::Type.type(:networkmanager_link).new(name: 'link', mac_address: 'aa:bb:cc:dd:ee:ff',
                                                             state: 'down')
      allow(Dir).to receive(:glob).with('/sys/class/net/*/address').and_return([])
      expect { resource.provider.state = :down }.to raise_error(Puppet::Error, %r{not found})
    end
  end

  describe '#state' do
    before { allow(Dir).to receive(:exist?).with('/sys/class/net/eno1').and_return(true) }

    def stub_device(up:, unmanaged: false)
      allow(execution).to receive(:execute).with(['/usr/sbin/ip', '-o', 'link', 'show', 'up', 'dev', 'eno1'], anything)
                                           .and_return(output(up ? "2: eno1: <UP>\n" : ''))
      allow(execution).to receive(:execute).with(['/usr/bin/nmcli', '-g', 'GENERAL.STATE', 'device', 'show', 'eno1'],
                                                 anything)
                                           .and_return(output(unmanaged ? "10 (unmanaged)\n" : "100 (connected)\n"))
    end

    context 'with the permanent unmanage support' do
      before { stub_nmcli(permanent: true) }

      it {
        stub_device(up: true)
        expect(provider.state).to eq(:managed)
      }
      it {
        stub_device(up: true, unmanaged: true)
        expect(provider.state).to eq(:unmanaged)
      }
      it {
        stub_device(up: false, unmanaged: true)
        expect(provider.state).to eq(:unmanaged_down)
      }
    end

    context 'without it' do
      before { stub_nmcli(permanent: false) }

      it {
        stub_device(up: true)
        expect(provider.state).to eq(:managed)
      }
      it {
        stub_device(up: false)
        expect(provider.state).to eq(:down)
      }
    end
  end

  describe '#state of a device which does not exist' do
    before do
      allow(Dir).to receive(:exist?).with('/sys/class/net/eno1').and_return(false)
      stub_nmcli(permanent: true)
    end

    it 'is missing, so both states are in sync and no command is run' do
      expect(execution).not_to receive(:execute).with(array_including('link'), anything)
      expect(provider.state).to eq(:missing)
    end

    it 'is not taken for an up link when ip prints its error (a failing ip, the device vanished after the check)' do
      allow(Dir).to receive(:exist?).with('/sys/class/net/eno1').and_return(true)
      allow(execution).to receive(:execute).with(['/usr/sbin/ip', '-o', 'link', 'show', 'up', 'dev', 'eno1'], anything)
                                           .and_return(output("Device \"eno1\" does not exist.\n", 1))
      allow(execution).to receive(:execute).with(['/usr/bin/nmcli', '-g', 'GENERAL.STATE', 'device', 'show', 'eno1'], anything)
                                           .and_return(output("Error: Device 'eno1' not found.\n", 10))
      expect(provider.link_up?('eno1')).to be(false)
      expect(provider.unmanaged?('eno1')).to be(false)
    end
  end

  describe '#device' do
    it 'finds the device by the MAC address' do
      resource = Puppet::Type.type(:networkmanager_link).new(name: 'link', mac_address: 'AA:BB:CC:DD:EE:FF',
                                                             state: 'down')
      allow(Dir).to receive(:glob).with('/sys/class/net/*/address').and_return(['/sys/class/net/lo/address',
                                                                                '/sys/class/net/eno7/address'])
      allow(File).to receive(:read).with('/sys/class/net/lo/address').and_return("00:00:00:00:00:00\n")
      allow(File).to receive(:read).with('/sys/class/net/eno7/address').and_return("aa:bb:cc:dd:ee:ff\n")
      expect(resource.provider.device).to eq('eno7')
    end

    context 'with the MAC address of more than one device or a device that vanishes' do
      let(:resource) { Puppet::Type.type(:networkmanager_link).new(name: 'link', mac_address: 'aa:bb:cc:dd:ee:ff', state: 'down') }

      it 'fails naming the devices' do
        allow(Dir).to receive(:glob).with('/sys/class/net/*/address').and_return(['/sys/class/net/bond0/address', '/sys/class/net/eno1/address'])
        allow(File).to receive(:read).and_return("aa:bb:cc:dd:ee:ff\n")
        expect { provider.device }.to raise_error(Puppet::Error, %r{more than one device \(bond0, eno1\)})
      end

      it 'ignores an interface which disappeared before it was read' do
        allow(Dir).to receive(:glob).with('/sys/class/net/*/address').and_return(['/sys/class/net/gone/address', '/sys/class/net/eno1/address'])
        allow(File).to receive(:read).with('/sys/class/net/gone/address').and_raise(Errno::ENOENT)
        allow(File).to receive(:read).with('/sys/class/net/eno1/address').and_return("AA:BB:CC:DD:EE:FF\n")
        expect(provider.device).to eq('eno1')
      end
    end
  end
end
