# frozen_string_literal: true

require 'spec_helper'

describe 'networkmanager::ifc::bridge::slave' do
  let(:title) { 'eth2slave' }
  let(:params) do
    { master: 'br0', interface_name: 'eth2' }
  end

  each_test_os do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to contain_networkmanager_keyfile('/etc/NetworkManager/system-connections/eth2slave.nmconnection').with_mode('0600') }
    end
  end

  context 'with the type of the master and the UUID of it' do
    let(:facts) { nm_test_facts('AlmaLinux', '9') }
    let(:file) { '/etc/NetworkManager/system-connections/eth2slave.nmconnection' }

    it { expect(keyfile_text(file)).to match(%r{^slave-type=bridge$}) }
    it { expect(keyfile_text(file)).to match(%r{^master=\h{8}-\h{4}-\h{4}-\h{4}-\h{12}$}) }
  end

  context 'with a master which is the connection itself' do
    let(:facts) { nm_test_facts('AlmaLinux', '9') }
    let(:params) { { master: 'eth2slave', interface_name: 'eth2' } }

    it { is_expected.to compile.and_raise_error(%r{is the connection itself}) }
  end

  context 'with ensure absent' do
    let(:facts) { nm_test_facts('AlmaLinux', '9') }

    context 'without the interface name and the mac address' do
      let(:params) { { master: 'br0', ensure: 'absent' } }

      it { is_expected.to compile.with_all_deps }
    end

    context 'with an invalid interface name' do
      let(:params) { { master: 'br0', ensure: 'absent', interface_name: 'bad:name' } }

      it { is_expected.to compile.and_raise_error(%r{interface_name}) }
    end
  end

  context 'with ensure present and without the interface name and the mac address' do
    let(:facts) { nm_test_facts('AlmaLinux', '9') }
    let(:params) { { master: 'br0' } }

    it { is_expected.to compile.and_raise_error(%r{either mac address or interface name}) }
  end
end
