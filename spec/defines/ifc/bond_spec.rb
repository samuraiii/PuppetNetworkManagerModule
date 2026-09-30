# frozen_string_literal: true

require 'spec_helper'

describe 'networkmanager::ifc::bond' do
  let(:title) { 'bond0' }
  let(:params) do
    { ipv6_method: 'ignore' }
  end

  each_test_os do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to contain_networkmanager_keyfile('/etc/NetworkManager/system-connections/bond0.nmconnection').with_mode('0600') }
    end
  end
end

describe 'networkmanager::ifc::bond' do
  let(:title) { 'bond0' }
  let(:facts) { nm_test_facts('AlmaLinux', '9') }

  context 'with the IPv6 method auto and no DUID or mac address' do
    it { is_expected.to compile.and_raise_error(%r{no mac_address was supplied}) }

    context 'and the class default unset' do
      let(:pre_condition) { "class { 'networkmanager': ipv6_dhcp_duid_default => 'unset' }" }

      it { expect(keyfile_text('/etc/NetworkManager/system-connections/bond0.nmconnection')).not_to match(%r{dhcp-duid}) }
    end
  end

  context 'with the IPv6 method auto and the mac address' do
    let(:params) { { mac_address: 'aa:bb:cc:dd:ee:ff' } }

    it { expect(keyfile_text('/etc/NetworkManager/system-connections/bond0.nmconnection')).to match(%r{^dhcp-duid=00:03:00:01:aa:bb:cc:dd:ee:ff$}) }
  end
end
