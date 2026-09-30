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

  describe 'the content property' do
    let(:resource) { described_class.new(path: path, content: content) }

    it 'is in sync when the checksum matches' do
      sum = resource.provider.checksum_of(content)
      expect(resource.property(:content).insync?(sum)).to be(true)
      expect(resource.property(:content).insync?('{sha256}other')).to be(false)
    end
  end
end
