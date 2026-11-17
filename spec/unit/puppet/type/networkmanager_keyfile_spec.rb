# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:networkmanager_keyfile) do
  let(:path) { '/etc/NetworkManager/system-connections/test.nmconnection' }
  let(:content) { { 'connection' => { 'id' => 'test' } } }

  it 'requires an absolute path' do
    expect { described_class.new(path: 'relative', content: content) }.to raise_error(Puppet::Error, %r{absolute})
  end

  it 'requires the content to be a hash of hashes' do
    expect { described_class.new(path: path, content: 'text') }.to raise_error(Puppet::Error, %r{hash of sections})
    expect { described_class.new(path: path, content: { 'a' => 'b' }) }
      .to raise_error(Puppet::Error, %r{hash of settings})
  end

  describe 'the names of the sections and the settings' do
    def build(content)
      described_class.new(path: path, content: content)
    end

    it 'accepts the names used by NetworkManager, also the section of a WireGuard peer with the base64 key' do
      expect { build('wireguard-peer.abc+/def=' => { 'endpoint' => 'x', 'allowed-ips' => 'y' }) }.not_to raise_error
      expect { build('vpn' => { 'ipsec-enabled' => 'yes', 'IPSec Secret' => 'x' }) }.not_to raise_error
    end

    ['#comment', ' lead', "\tlead", '[section]', '', 'a=b', "a\nb"].each do |key|
      it "refuses the setting name #{key.inspect}" do
        expect { build('connection' => { key => 'x' }) }.to raise_error(Puppet::Error, %r{Invalid setting name})
      end
    end

    ['a[b', 'a]b', "a\nb"].each do |section|
      it "refuses the section name #{section.inspect}" do
        expect { build(section => { 'a' => 'b' }) }.to raise_error(Puppet::Error, %r{Invalid section name})
      end
    end
  end

  it 'has the defaults' do
    resource = described_class.new(path: path, content: content)
    expect(resource[:mode]).to eq('0600')
    expect(resource[:owner]).to eq('root')
    expect(resource[:group]).to eq('root')
    expect(resource[:show_diff]).to be(true)
    expect(resource[:header]).to eq('# THIS FILE IS CONTROLLED BY PUPPET')
  end

  it 'normalises the mode' do
    expect(described_class.new(path: path, content: content, mode: '600')[:mode]).to eq('0600')
  end

  it 'refuses a mode which is not a string' do
    expect { described_class.new(path: path, content: content, mode: 420) }.to raise_error(Puppet::Error, %r{must be a string})
  end

  describe 'the values of the settings' do
    def build(settings, extra = {})
      described_class.new({ path: path, content: { 'ipv4' => settings } }.merge(extra))
    end

    it 'accepts the strings, numbers, booleans, nil and arrays of them' do
      expect { build({ 'a' => 'x', 'b' => 1, 'c' => true, 'd' => nil, 'e' => ['1.1.1.1', 2] }) }.not_to raise_error
    end

    it 'refuses a nested array, naming the section and the setting' do
      expect { build({ 'route' => [['10.0.0.0/8', '10.0.0.1']] }) }
        .to raise_error(Puppet::Error, %r{setting 'route' in the section 'ipv4'})
    end

    it 'refuses a hash' do
      expect { build({ 'route' => { 'a' => 'b' } }) }.to raise_error(Puppet::Error, %r{not Hash})
    end

    it 'does not check the content of a connection which is removed' do
      expect { build({ 'route' => { 'a' => 'b' } }, { ensure: :absent }) }.not_to raise_error
    end
  end

  describe 'the content property' do
    let(:resource) { described_class.new(path: path, content: content) }

    it 'is in sync when the checksum matches' do
      sum = resource.provider.checksum_of(content)
      expect(resource.property(:content).insync?(sum)).to be(true)
      expect(resource.property(:content).insync?('{sha256}other')).to be(false)
    end
  end
end
