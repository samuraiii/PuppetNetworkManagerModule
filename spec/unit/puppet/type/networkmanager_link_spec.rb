# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:networkmanager_link) do
  let(:type) { described_class }

  it 'needs the interface name or the mac address' do
    expect do
      type.new(name: 'link', state: 'down')
    end.to raise_error(Puppet::Error, %r{Either interface_name or mac_address})
  end

  it 'refuses an invalid interface name' do
    expect do
      type.new(name: 'link', interface_name: 'eth0:1',
               state: 'down')
    end.to raise_error(Puppet::Error, %r{Invalid interface name})
    expect do
      type.new(name: 'link', interface_name: '-batch',
               state: 'down')
    end.to raise_error(Puppet::Error, %r{Invalid interface name})
  end

  it 'refuses an invalid mac address and downcases a valid one' do
    expect do
      type.new(name: 'link', mac_address: 'aa:bb', state: 'down')
    end.to raise_error(Puppet::Error, %r{Invalid MAC address})
    expect(type.new(name: 'link', mac_address: 'AA:BB:CC:DD:EE:FF',
                    state: 'down')[:mac_address]).to eq('aa:bb:cc:dd:ee:ff')
  end

  it 'accepts the MAC address with the dashes and the 20 bytes of an InfiniBand device, in the form with the colons' do
    expect(type.new(name: 'link', mac_address: 'AA-BB-CC-DD-EE-FF', state: 'down')[:mac_address]).to eq('aa:bb:cc:dd:ee:ff')
    infiniband = Array.new(20) { |i| format('%02x', i) }.join(':')
    expect(type.new(name: 'link', mac_address: infiniband, state: 'down')[:mac_address]).to eq(infiniband)
  end

  describe 'the state property' do
    def state(should)
      type.new(name: 'link', interface_name: 'eno1', state: should).property(:state)
    end

    it 'is in sync for down when the link is down, also when the device is unmanaged' do
      expect(state('down').insync?(:down)).to be(true)
      expect(state('down').insync?(:unmanaged_down)).to be(true)
      expect(state('down').insync?(:managed)).to be(false)
      expect(state('down').insync?(:unmanaged)).to be(false)
    end

    it 'is in sync for a device which does not exist, in both states' do
      expect(state('down').insync?(:missing)).to be(true)
      expect(state('managed').insync?(:missing)).to be(true)
    end

    it 'is out of sync for managed when the device was unmanaged or its link was shut down' do
      expect(state('managed').insync?(:managed)).to be(true)
      expect(state('managed').insync?(:down)).to be(false)
      expect(state('managed').insync?(:unmanaged)).to be(false)
      expect(state('managed').insync?(:unmanaged_down)).to be(false)
    end
  end
end
