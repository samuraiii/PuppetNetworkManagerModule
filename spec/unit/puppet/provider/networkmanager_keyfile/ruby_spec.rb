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
        session-cookie=ck1
        user-credentials=cr2
        apikey=ak3
        Api-Key=ak4
        auth_key=ak5
        authkey=ak6
        author=bob
      INI
      censored = provider.censor(text)
      %w[hunter2 abcde s3cret AAAA BBBB zzz here ck1 cr2 ak3 ak4 ak5 ak6].each { |secret| expect(censored).not_to include(secret) }
      expect(censored).to include('key-mgmt=wpa-psk', 'identity=alice', 'eap=peap', 'author=bob')
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

    context 'with a mode set' do
      let(:extra) { { mode: '0644' } }

      it 'keeps the mode when the content changes' do
        provider.create
        provider.content = { 'connection' => { 'id' => 'changed' } }
        expect(format('%04o', File.stat(path).mode & 0o7777)).to eq('0644')
      end
    end

    it 'uses the mode 0600 for a new file without the mode' do
      provider.content = content
      expect(format('%04o', File.stat(path).mode & 0o7777)).to eq('0600')
    end

    context 'with the names of the secret settings given by the user' do
      let(:extra) { { secret_keys: ['My-Token-X'] } }

      it 'censors them whatever the case is' do
        text = "[connection]\nmy-token-x=abc\nid=test\n"
        expect(provider.censor(text)).to eq("[connection]\nmy-token-x=<redacted>\nid=test\n")
      end
    end

    it 'censors the MACsec keys, but not similar names' do
      text = "[macsec]\nmka-cak=1\nmka-ckn=2\nmka-can=3\nmka-ca=4\n"
      expect(provider.censor(text)).to eq("[macsec]\nmka-cak=<redacted>\nmka-ckn=<redacted>\nmka-can=3\nmka-ca=4\n")
    end

    it 'lists only the *.nmconnection files of the default directory' do
      allow(described_class).to receive(:connections_dir).and_return(dir)
      %w[a.nmconnection b.nmconnection readme.txt c.nmconnection~].each { |name| File.write(File.join(dir, name), '') }
      expect(described_class.instances.map(&:name).map { |name| File.basename(name) }).to eq(%w[a.nmconnection b.nmconnection])
    end

    it 'reports a change of the secrets only as such' do
      allow(Puppet::Util::Diff).to receive(:diff) { |old, new| Open3.capture2('diff', '-u', old, new).first }
      first = { 'wifi-security' => { 'psk' => 'one' } }
      provider.create
      provider.content = first
      expect(provider.diff({ 'wifi-security' => { 'psk' => 'two' } })).to eq('(only the values of the censored secrets differ)')
    end

    it 'has no checksum, mode, owner and group for a file which does not exist' do
      expect([provider.checksum, provider.mode, provider.owner, provider.group]).to eq(%i[absent absent absent absent])
    end

    it 'fails with a clear message for a user or a group which does not exist' do
      provider.create
      expect { provider.owner = 'no_such_user_xyz' }.to raise_error(Puppet::Error, %r{user 'no_such_user_xyz'})
      expect { provider.group = 'no_such_group_xyz' }.to raise_error(Puppet::Error, %r{group 'no_such_group_xyz'})
    end
  end
end

describe Puppet::Type.type(:networkmanager_keyfile).provider(:ruby), 'the detection of the disabled IPv6 method' do
  let(:execution) { Puppet::Util::Execution }

  # the specs set the memo, the detection itself is tested here with the memo removed and restored
  around do |example|
    memo = described_class.instance_variable_get(:@ipv6_disabled_supported)
    described_class.remove_instance_variable(:@ipv6_disabled_supported)
    example.run
  ensure
    described_class.instance_variable_set(:@ipv6_disabled_supported, memo)
  end

  def stub_nmcli(output)
    allow(Puppet::Util).to receive(:which).with('nmcli').and_return('/usr/bin/nmcli')
    allow(execution).to receive(:execute).with(['/usr/bin/nmcli', '--version'], anything).and_return(output)
  end

  it 'is supported from NetworkManager 1.20' do
    stub_nmcli("nmcli tool, version 1.20.0\n")
    expect(described_class.ipv6_disabled_supported?).to be(true)
  end

  it 'is supported for a newer version with a release suffix' do
    stub_nmcli("nmcli tool, version 1.46.0-1.el9\n")
    expect(described_class.ipv6_disabled_supported?).to be(true)
  end

  it 'is not supported for NetworkManager older than 1.20' do
    stub_nmcli("nmcli tool, version 1.18.8\n")
    expect(described_class.ipv6_disabled_supported?).to be(false)
  end

  it 'compares the numbers, not the text (1.9 is older than 1.20)' do
    stub_nmcli("nmcli tool, version 1.9.2\n")
    expect(described_class.ipv6_disabled_supported?).to be(false)
  end

  it 'fails for an output which is not understood' do
    stub_nmcli("something else\n")
    expect { described_class.ipv6_disabled_supported? }.to raise_error(Puppet::Error, %r{can not read the NetworkManager version})
  end

  it 'fails without nmcli' do
    allow(Puppet::Util).to receive(:which).with('nmcli').and_return(nil)
    expect { described_class.ipv6_disabled_supported? }.to raise_error(Puppet::Error, %r{nmcli not found})
  end

  it 'asks nmcli only once' do
    stub_nmcli("nmcli tool, version 1.46.0\n")
    2.times { described_class.ipv6_disabled_supported? }
    expect(execution).to have_received(:execute).once
  end
end
