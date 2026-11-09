# frozen_string_literal: true

require 'spec_helper'

# the activation, the deactivation and the removal of the connections, and the order of the activations
describe 'networkmanager::ifc::connection' do
  let(:title) { 'eth0conn' }
  let(:facts) { nm_test_facts('AlmaLinux', '9') }
  let(:base) { { interface_name: 'eth0', ipv4_method: 'auto', ipv6_method: 'ignore' } }
  let(:path) { '/etc/NetworkManager/system-connections/eth0conn.nmconnection' }

  def uuid
    catalogue.resource('Networkmanager_keyfile', path)[:content]['connection']['uuid']
  end

  context 'with ensure absent' do
    let(:params) { base.merge(ensure: 'absent') }

    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_networkmanager_keyfile(path).with_ensure('absent') }

    it 'deactivates the connection before its keyfile is removed' do
      is_expected.to contain_exec("deactivate connection #{uuid}")
        .with_onlyif(%r{nmcli -t -f GENERAL con show #{uuid} \| /usr/bin/grep 'GENERAL.STATE:activated'})
        .with_command(%r{nmcli connection down #{uuid}\z})
        .that_comes_before("Networkmanager_keyfile[#{path}]")
    end

    it 'makes NetworkManager forget the connection after the keyfile was removed' do
      is_expected.to contain_exec("forget connection #{uuid}")
        .without_refreshonly.with_command('/usr/bin/nmcli connection reload').that_subscribes_to("Networkmanager_keyfile[#{path}]")
    end

    it { is_expected.not_to contain_exec("activate connection always #{uuid}") }
    # a device unmanaged by an earlier state down would stay so
    it 'gives the device back to NetworkManager' do
      is_expected.to contain_networkmanager_link("link of connection #{uuid}").with(interface_name: 'eth0', state: 'managed').without_before.without_require
    end
  end

  context 'with the state down' do
    let(:params) { base.merge(state: 'down') }

    # the same keyfile as with the state up: the exec must not wait for a change of the keyfile
    it 'deactivates the connection on every run it is active' do
      is_expected.to contain_exec("deactivate connection #{uuid}")
        .without_refreshonly.with_onlyif(%r{GENERAL.STATE:activated}).that_requires("Networkmanager_keyfile[#{path}]")
    end
  end

  context 'with the state up' do
    let(:params) { base }

    it { is_expected.to contain_exec("activate connection always #{uuid}").with_unless(%r{GENERAL.STATE:activated}) }
    it { is_expected.to contain_exec("activate connection after initial config #{uuid}").with_refreshonly(true) }
  end
end

describe 'networkmanager::ifc::connection' do
  let(:title) { 'eth0conn' }
  let(:facts) { nm_test_facts('AlmaLinux', '9') }
  let(:params) { { interface_name: 'eth0', ipv4_method: 'auto', ipv6_method: 'ignore', additional_config: { 'connection' => { 'uuid' => '11111111-2222-3333-4444-555555555555' } } } }

  it { is_expected.to compile.and_raise_error(%r{can not set the connection\.uuid}) }
end

describe 'networkmanager::ifc::connection' do
  let(:title) { 'wlan0conn' }
  let(:facts) { nm_test_facts('AlmaLinux', '9') }
  let(:path) { '/etc/NetworkManager/system-connections/wlan0conn.nmconnection' }

  context 'with a wifi connection and a mac address' do
    let(:params) { { type: 'wifi', mac_address: 'aa:bb:cc:dd:ee:ff', ipv4_method: 'auto', ipv6_method: 'ignore' } }

    it 'writes the mac address into the wireless section, not into the ethernet one' do
      content = catalogue.resource('Networkmanager_keyfile', path)[:content]
      expect(content).to include('802-11-wireless' => { 'mac-address' => 'aa:bb:cc:dd:ee:ff' })
      expect(content).not_to include('ethernet')
    end
  end

  context 'with a connection type which has no known section for the mac address' do
    let(:params) { { type: 'dummy', interface_name: 'dummy0', mac_address: 'aa:bb:cc:dd:ee:ff', ipv4_method: 'auto', ipv6_method: 'ignore' } }

    it { is_expected.to compile.and_raise_error(%r{mac_address can not be set for the connection type 'dummy'}) }
  end
end

# the master is activated before its ports, the parent before the vlan
describe 'networkmanager::ifc::bond::slave' do
  let(:title) { 'eth1slave' }
  let(:facts) { nm_test_facts('AlmaLinux', '9') }
  let(:params) { { master: 'bond0', interface_name: 'eth1' } }
  let(:pre_condition) { 'networkmanager::ifc::bond { "bond0": ipv6_method => "ignore" }' }

  def uuid(id)
    catalogue.resource('Networkmanager_keyfile', "/etc/NetworkManager/system-connections/#{id}.nmconnection")[:content]['connection']['uuid']
  end

  it { is_expected.to compile.with_all_deps }

  it 'activates the slave after the master' do
    is_expected.to contain_exec("activate connection after initial config #{uuid('eth1slave')}")
      .that_requires("Exec[activate connection always #{uuid('bond0')}]")
  end
end

describe 'networkmanager::ifc::vlan' do
  let(:title) { 'vlan100' }
  let(:facts) { nm_test_facts('AlmaLinux', '9') }
  let(:params) { { vlan_id: 100, vlan_parent: 'uplink0', mac_address: 'aa:bb:cc:dd:ee:ff', interface_name: 'vlan100' } }
  let(:pre_condition) { 'networkmanager::ifc::connection { "uplink0": interface_name => "eth0", ipv6_method => "ignore" }' }

  def uuid(id)
    catalogue.resource('Networkmanager_keyfile', "/etc/NetworkManager/system-connections/#{id}.nmconnection")[:content]['connection']['uuid']
  end

  it { is_expected.to compile.with_all_deps }

  it 'activates the vlan after its parent' do
    is_expected.to contain_exec("activate connection after initial config #{uuid('vlan100')}")
      .that_requires("Exec[activate connection always #{uuid('uplink0')}]")
  end
end

# the same lifecycle for every kind of connection
{
  'networkmanager::ifc::bond' => ['bond0', { ipv6_method: 'ignore' }],
  'networkmanager::ifc::bridge' => ['br0', { ipv6_method: 'ignore' }],
  'networkmanager::ifc::vlan' => ['vlan100', { vlan_id: 100, vlan_parent: 'uplink0', mac_address: 'aa:bb:cc:dd:ee:ff' }],
  'networkmanager::ifc::bond::slave' => ['slave0', { master: 'bond0', interface_name: 'eth1' }],
  'networkmanager::ifc::bridge::slave' => ['slave1', { master: 'br0', mac_address: 'aa:bb:cc:dd:ee:ff' }],
}.each do |define, (name, base)|
  describe define do
    let(:title) { name }
    let(:facts) { nm_test_facts('AlmaLinux', '9') }
    let(:path) { "/etc/NetworkManager/system-connections/#{name}.nmconnection" }

    def uuid
      catalogue.resource('Networkmanager_keyfile', path)[:content]['connection']['uuid']
    end

    context 'with ensure absent' do
      let(:params) { base.merge(ensure: 'absent') }

      it { is_expected.to compile.with_all_deps }

      it 'deactivates the connection before the keyfile is removed and forgets it afterwards' do
        is_expected.to contain_exec("deactivate connection #{uuid}").with_onlyif(%r{GENERAL.STATE:activated}).that_comes_before("Networkmanager_keyfile[#{path}]")
        is_expected.to contain_exec("forget connection #{uuid}").without_refreshonly.that_subscribes_to("Networkmanager_keyfile[#{path}]")
      end

      it { is_expected.not_to contain_exec("activate connection always #{uuid}") }
      it { is_expected.to contain_networkmanager_link("link of connection #{uuid}").with_state('managed').without_before.without_require }
    end

    context 'with the state down' do
      let(:params) { base.merge(state: 'down') }

      it 'deactivates the connection whenever it is active, and shuts the link down after that' do
        is_expected.to contain_exec("deactivate connection #{uuid}").without_refreshonly.with_onlyif(%r{GENERAL.STATE:activated})
        is_expected.to contain_networkmanager_link("link of connection #{uuid}").with_state('down').that_requires("Exec[deactivate connection #{uuid}]")
      end
    end

    context 'with the state up' do
      let(:params) { base }

      it 'lets NetworkManager manage the device before the activation' do
        is_expected.to contain_networkmanager_link("link of connection #{uuid}").with_state('managed')
                                                                                .that_comes_before("Exec[activate connection after initial config #{uuid}]")
      end

      it { is_expected.to contain_exec("activate connection always #{uuid}").with_unless(%r{GENERAL.STATE:activated}) }
    end
  end
end

describe 'networkmanager::ifc::bridge::slave' do
  let(:title) { 'slave1' }
  let(:facts) { nm_test_facts('AlmaLinux', '9') }
  let(:params) { { master: 'br0', mac_address: 'AA-BB-CC-DD-EE-FF', state: 'down' } }

  it 'accepts the MAC address with the dashes, as the type does' do
    link = catalogue.resources.find { |r| 'Networkmanager_link' == r.type }
    expect(link[:mac_address]).to eq('AA-BB-CC-DD-EE-FF')
    expect(link.to_ral[:mac_address]).to eq('aa:bb:cc:dd:ee:ff')
  end
end

describe 'networkmanager::ifc::fallback' do
  let(:title) { 'fallback0' }
  let(:facts) { nm_test_facts('AlmaLinux', '9') }
  let(:path) { '/etc/NetworkManager/system-connections/fallback0.nmconnection' }

  context 'with an interface name from YAML which is a number' do
    let(:params) { { config: { 'connection' => { 'interface-name' => 1234 } } } }

    it { is_expected.to compile.with_all_deps }
  end

  context 'with the uuid set in the config' do
    let(:params) { { config: { 'connection' => { 'uuid' => '11111111-2222-3333-4444-555555555555' } } } }

    it 'activates the uuid of the config' do
      is_expected.to contain_exec('activate connection always 11111111-2222-3333-4444-555555555555')
    end
  end

  context 'with a uuid in the config which is not an UUID' do
    let(:params) { { config: { 'connection' => { 'uuid' => 'not-a-uuid' } } } }

    it { is_expected.to compile.and_raise_error(%r{must be an UUID}) }
  end

  context 'with ensure absent' do
    let(:params) { { config: { 'ipv4' => { 'method' => 'auto' } }, ensure: 'absent' } }

    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_exec("forget connection #{catalogue.resource('Networkmanager_keyfile', path)[:content]['connection']['uuid']}") }
  end

  context 'with the default config' do
    let(:params) { { config: { 'ipv4' => { 'method' => 'auto' } } } }

    it 'is ordered after the class networkmanager, without a cycle' do
      is_expected.to compile.with_all_deps
      is_expected.to contain_networkmanager_keyfile(path).that_requires('Class[networkmanager]')
    end
  end
end

# the values NetworkManager does not accept are refused when the catalog is compiled
{
  'networkmanager::ifc::vlan' => [{ vlan_id: 100, vlan_parent: 'uplink0', mac_address: 'aa:bb:cc:dd:ee:ff' }, { vlan_id: 0 }, { vlan_id: 4095 }, { vlan_flags: 16 }],
  'networkmanager::ifc::bridge' => [{ ipv6_method: 'ignore' }, { bridge_forward_delay: 31 }, { ipv6_addr_gen_mode: 4 }, { ipv6_privacy: 3 }],
  'networkmanager::ifc::bond' => [{ ipv6_method: 'ignore' }, { bond_mode: 7 }, { bond_mode: 'nonsense' }, { interface_name: 'bad:name' }],
}.each do |define, (good, *bad)|
  describe define do
    let(:title) { 'conn1' }
    let(:facts) { nm_test_facts('AlmaLinux', '9') }

    bad.each do |params|
      context "with #{params}" do
        let(:params) { good.merge(params) }

        it { is_expected.to compile.and_raise_error(%r{expects}) }
      end
    end
  end
end

# a connection which is a port of another one needs the type of the controller
{
  'networkmanager::ifc::connection' => ['conn1', { interface_name: 'eth0', ipv6_method: 'ignore' }],
  'networkmanager::ifc::bond' => ['bond0', { ipv6_method: 'ignore' }],
  'networkmanager::ifc::bridge' => ['br0', { ipv6_method: 'ignore' }],
}.each do |define, (name, base)|
  describe define do
    let(:title) { name }
    let(:facts) { nm_test_facts('AlmaLinux', '9') }
    let(:path) { "/etc/NetworkManager/system-connections/#{name}.nmconnection" }

    context 'with a master and the slave_type' do
      let(:params) { base.merge(master: 'outer0', slave_type: 'bridge') }

      it 'writes the master and the slave-type' do
        connection = catalogue.resource('Networkmanager_keyfile', path)[:content]['connection']
        expect(connection).to include('slave-type' => 'bridge')
        expect(connection['master']).to match(%r{\A\h{8}-(\h{4}-){3}\h{12}\z})
      end
    end

    context 'with a master and without the slave_type' do
      let(:params) { base.merge(master: 'outer0') }

      it { is_expected.to compile.and_raise_error(%r{has the master 'outer0' but no slave_type}) }
    end

    context 'with the slave_type and without a master' do
      let(:params) { base.merge(slave_type: 'bridge') }

      it 'writes neither of them' do
        expect(catalogue.resource('Networkmanager_keyfile', path)[:content]['connection']).not_to include('master', 'slave-type')
      end
    end

    context 'with an unknown slave_type' do
      let(:params) { base.merge(master: 'outer0', slave_type: 'bondage') }

      it { is_expected.to compile.and_raise_error(%r{slave_type}) }
    end
  end
end

describe 'networkmanager::ifc::vlan' do
  let(:title) { 'vlan100' }
  let(:facts) { nm_test_facts('AlmaLinux', '9') }
  let(:path) { '/etc/NetworkManager/system-connections/vlan100.nmconnection' }

  context 'with a master, the slave_type is bridge by default' do
    let(:params) { { vlan_id: 100, vlan_parent: 'uplink0', master: 'br0' } }

    it { expect(catalogue.resource('Networkmanager_keyfile', path)[:content]['connection']).to include('slave-type' => 'bridge') }
  end

  context 'with a bond as the master' do
    let(:params) { { vlan_id: 100, vlan_parent: 'uplink0', master: 'bond0', slave_type: 'bond' } }

    it { expect(catalogue.resource('Networkmanager_keyfile', path)[:content]['connection']).to include('slave-type' => 'bond') }
  end
end
