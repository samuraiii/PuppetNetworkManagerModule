# frozen_string_literal: true

require 'spec_helper'

describe 'networkmanager::ifc::vlan' do
  let(:title) { 'vlan100' }
  let(:params) do
    { vlan_id: 100, vlan_parent: 'eth0conn', mac_address: 'aa:bb:cc:dd:ee:ff' }
  end

  each_test_os do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to contain_networkmanager_keyfile('/etc/NetworkManager/system-connections/vlan100.nmconnection').with_mode('0600') }
    end
  end
end

describe 'networkmanager::ifc::vlan' do
  let(:title) { 'vlan100' }
  let(:facts) { nm_test_facts('AlmaLinux', '9') }
  let(:file) { '/etc/NetworkManager/system-connections/vlan100.nmconnection' }

  # NetworkManager expects the plain UUID in vlan.parent, a "UUID=" prefix is rejected by it
  context 'with a connection UUID as the parent' do
    let(:params) { { vlan_id: 100, vlan_parent: '0f2a1c3e-1111-4222-8333-444455556666', mac_address: 'aa:bb:cc:dd:ee:ff' } }

    it { expect(keyfile_text(file)).to match(%r{^parent=0f2a1c3e-1111-4222-8333-444455556666$}) }
    it { expect(keyfile_text(file)).not_to match(%r{UUID=}) }
  end

  context 'with a connection id as the parent' do
    let(:params) { { vlan_id: 100, vlan_parent: 'eth0conn', mac_address: 'aa:bb:cc:dd:ee:ff' } }

    it { expect(keyfile_text(file)).to match(%r{^parent=\h{8}-\h{4}-\h{4}-\h{4}-\h{12}$}) }
    it { expect(keyfile_text(file)).not_to match(%r{^parent=eth0conn$}) }
  end
end

describe 'networkmanager::ifc::vlan' do
  let(:title) { 'vlan100' }
  let(:facts) { nm_test_facts('AlmaLinux', '9') }

  context 'with the vlan_parent which is the connection itself' do
    let(:params) { { vlan_id: 100, vlan_parent: 'vlan100' } }

    it { is_expected.to compile.and_raise_error(%r{vlan_parent 'vlan100' of the connection 'vlan100' is the connection itself}) }
  end

  context 'with the master which is the connection itself' do
    let(:params) { { vlan_id: 100, vlan_parent: 'eth0conn', master: 'vlan100' } }

    it { is_expected.to compile.and_raise_error(%r{master 'vlan100' of the connection 'vlan100' is the connection itself}) }
  end
end

describe 'networkmanager::ifc::vlan' do
  let(:title) { 'vlan100' }
  let(:facts) { nm_test_facts('AlmaLinux', '9') }
  let(:file) { '/etc/NetworkManager/system-connections/vlan100.nmconnection' }
  let(:base) { { vlan_id: 100, vlan_parent: 'eth0conn', mac_address: 'aa:bb:cc:dd:ee:ff' } }

  context 'without the mac address (the DUID is tied to it, as for the other connections)' do
    let(:params) { { vlan_id: 100, vlan_parent: 'eth0conn' } }

    it { is_expected.to compile.and_raise_error(%r{no mac_address was supplied}) }
  end

  context 'with the defaults' do
    let(:params) { base }

    it { expect(keyfile_text(file)).to match(%r{\[ipv4\]\nmethod=auto$}m) }
    it { expect(keyfile_text(file)).to match(%r{\[ipv6\]\nmethod=auto$}m) }
    it { expect(keyfile_text(file)).to match(%r{^addr-gen-mode=eui64$|^addr-gen-mode=0$}) }
    it { expect(keyfile_text(file)).to match(%r{^ip6-privacy=0$}) }
    it { expect(keyfile_text(file)).to match(%r{^dhcp-duid=00:03:00:01:aa:bb:cc:dd:ee:ff$}) }
  end

  context 'with the mac address of the parent in another spelling' do
    let(:params) { base.merge(mac_address: 'AA-BB-CC-DD-EE-FF') }

    it { expect(keyfile_text(file)).to match(%r{^dhcp-duid=00:03:00:01:aa:bb:cc:dd:ee:ff$}) }
    it { expect(keyfile_text(file)).not_to match(%r{mac-address}) }
    it 'looks up the link by the name, the MAC address is the one of the parent too' do
      expect(catalogue.resources.select { |r| 'Networkmanager_link' == r.type }.map { |r| r[:mac_address] }).to eq([nil])
    end
  end

  context 'with the DUID unset' do
    let(:params) { { vlan_id: 100, vlan_parent: 'eth0conn', ipv6_dhcp_duid: 'unset' } }

    it { expect(keyfile_text(file)).not_to match(%r{dhcp-duid}) }
  end

  context 'with static addresses' do
    let(:params) do
      base.merge(ipv4_method: 'manual', ipv4_address: '192.0.2.12/24', ipv4_gateway: '192.0.2.1', ipv4_dns: '192.0.2.53',
                 ipv6_method: 'manual', ipv6_address: '2001:db8::12/64', ipv6_gateway: '2001:db8::1')
    end

    it { expect(keyfile_text(file)).to match(%r{^address=192\.0\.2\.12/24$}) }
    it { expect(keyfile_text(file)).to match(%r{^gateway=192\.0\.2\.1$}) }
    it { expect(keyfile_text(file)).to match(%r{^address=2001:db8::12/64$}) }
  end

  context 'with an explicit DUID' do
    let(:params) { base.merge(ipv6_dhcp_duid: 'll') }

    it { expect(keyfile_text(file)).to match(%r{^dhcp-duid=ll$}) }
  end

  context 'as a port of a bridge' do
    let(:params) { base.merge(master: 'br0', slave_type: 'bridge') }

    it { expect(keyfile_text(file)).to match(%r{\[ipv4\]\nmethod=disabled$}m) }
    it { expect(keyfile_text(file)).to match(%r{\[ipv6\]\nmethod=ignore$}m) }
  end

  context 'with a wrong address' do
    let(:params) { base.merge(ipv4_method: 'manual', ipv4_address: '300.0.0.1/24') }

    it { is_expected.to compile.and_raise_error(%r{expects}) }
  end
end
