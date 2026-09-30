# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'tmpdir'

describe Puppet::Type.type(:networkmanager_keyfile).provider(:ruby) do
  let(:dir) { Dir.mktmpdir }
  let(:path) { File.join(dir, 'test.nmconnection') }
  let(:content) { { 'connection' => { 'id' => 'test' } } }
  let(:extra) { {} }
  let(:resource) do
    attributes = { path: path, content: content, owner: Etc.getpwuid.name, group: Etc.getgrgid(Process.gid).name }
    Puppet::Type.type(:networkmanager_keyfile).new(attributes.merge(extra))
  end
  let(:provider) { resource.provider }

  after { FileUtils.remove_entry(dir) }

  describe '#ini_value' do
    {
      nil => '',
      '' => '',
      'eth0' => 'eth0',
      true => 'true',
      false => 'false',
      5 => '5',
      'with space inside' => 'with space inside',
      '"kept as is"' => '"kept as is"',
      '8.8.8.8;' => '8.8.8.8;',
      'a\\b' => 'a\\\\b',
      "l1\nl2" => 'l1\\nl2',
      "a\tb" => 'a\\tb',
      "a\rb" => 'a\\rb',
      '  x' => '\\s x',
      'x  ' => 'x \\s',
      %w[a b] => 'a;b;',
      ['a;b', 'c'] => 'a\;b;c;',
      ['a', 1, true] => 'a;1;true;',
      [] => '',
    }.each do |value, expected|
      it "formats #{value.inspect} as #{expected.inspect}" do
        expect(provider.ini_value(value)).to eq(expected)
      end
    end

    it 'refuses a hash' do
      expect { provider.ini_value({ 'a' => 1 }) }.to raise_error(Puppet::Error)
    end
  end

  describe '#render' do
    let(:content) do
      { 'connection' => { 'id' => 'test', 'autoconnect' => true }, 'ipv4' => { 'dns' => %w[1.1.1.1 8.8.8.8] } }
    end

    it 'renders the header, the sections and the settings' do
      expect(provider.render(content)).to eq(<<~INI)
        # THIS FILE IS CONTROLLED BY PUPPET

        [connection]
        id=test
        autoconnect=true

        [ipv4]
        dns=1.1.1.1;8.8.8.8;

      INI
    end

    context 'with the disabled IPv6 method' do
      let(:content) { { 'ipv6' => { 'method' => 'disabled' } } }

      it 'keeps it when NetworkManager supports it' do
        allow(described_class).to receive(:ipv6_disabled_supported?).and_return(true)
        expect(provider.render(content)).to match(%r{^method=disabled$})
      end

      it 'changes it to ignore for NetworkManager older than 1.20' do
        allow(described_class).to receive(:ipv6_disabled_supported?).and_return(false)
        expect(provider.render(content)).to match(%r{^method=ignore$})
      end
    end
  end

  describe '#censor' do
    let(:extra) { { secret_keys: ['my-token-like'] } }

    it 'censors the secrets of wifi, 802.1x, vpn and wireguard connections and the custom keys' do
      text = <<~INI
        [wifi-security]
        key-mgmt=wpa-psk
        psk=hunter2
        wep-key0=abcde
        leap-password=x
        [802-1x]
        eap=peap
        identity=alice
        password=s3cret
        private-key-password=pk
        [vpn]
        service-type=org.freedesktop.NetworkManager.openvpn
        [vpn-secrets]
        anything=here
        [wireguard]
        private-key=AAAA
        [wireguard-peer.PUB]
        preshared-key=BBBB
        [other]
        my-token-like=zzz
      INI
      censored = provider.censor(text)
      %w[hunter2 abcde s3cret AAAA BBBB zzz here].each { |secret| expect(censored).not_to include(secret) }
      expect(censored).to include('key-mgmt=wpa-psk', 'identity=alice', 'eap=peap')
      expect(censored).to include('psk=<redacted>', 'anything=<redacted>')
    end
  end

  describe 'the file' do
    it 'is created with the mode 0600 and the content' do
      provider.create
      expect(File.read(path)).to eq(provider.render(content))
      expect(File.stat(path).mode & 0o7777).to eq(0o600)
    end

    it 'reports only the checksum of the content' do
      provider.create
      expect(provider.checksum).to eq(provider.checksum_of(content))
      expect(provider.checksum).to match(%r{\A\{sha256\}\h{64}\z})
    end

    it 'is rewritten when the content changes' do
      provider.create
      provider.content = { 'connection' => { 'id' => 'other' } }
      expect(File.read(path)).to match(%r{^id=other$})
    end

    it 'is removed' do
      provider.create
      provider.destroy
      expect(File).not_to exist(path)
    end

    it 'has no diff for a file which does not exist' do
      expect(provider.diff(content)).to eq('')
    end

    it 'has the secrets censored in the diff' do
      # the command execution of Puppet is stubbed in the specs
      allow(Puppet::Util::Diff).to receive(:diff) { |old, new| Open3.capture2('diff', '-u', old, new).first }
      provider.create
      new = { 'connection' => { 'id' => 'other' }, 'wifi-security' => { 'psk' => 'hunter2' } }
      diff = provider.diff(new)
      expect(diff).to include('+id=other')
      expect(diff).not_to include('hunter2')
    end
  end
end
