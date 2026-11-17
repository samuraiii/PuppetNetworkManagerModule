# frozen_string_literal: true

require 'spec_helper'

describe 'networkmanager::ifc::fallback' do
  let(:title) { 'fallback0' }
  let(:params) do
    { config: { 'ipv4' => { 'method' => 'auto' } } }
  end

  each_test_os do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to contain_networkmanager_keyfile('/etc/NetworkManager/system-connections/fallback0.nmconnection').with_mode('0600') }
    end
  end

  context 'with the content' do
    let(:facts) { nm_test_facts('AlmaLinux', '9') }
    let(:path) { '/etc/NetworkManager/system-connections/fallback0.nmconnection' }
    let(:params) do
      { config: { 'connection' => { 'interface-name' => 'eth0' }, 'ethernet' => { 'mac-address' => 'aa:bb:cc:dd:ee:ff' },
                  'vlan' => { 'id' => 5, 'parent' => 'bond0' } } }
    end

    def content
      catalogue.resource('Networkmanager_keyfile', path)[:content]
    end

    it 'keeps the defaults, the passed sections and the translated parent' do
      expect(content['connection']).to include('id' => 'fallback0', 'type' => 'ethernet', 'interface-name' => 'eth0')
      expect(content['connection']['uuid']).to match(%r{\A\h{8}-(\h{4}-){3}\h{12}\z})
      expect(content['ethernet']).to include('mac-address' => 'aa:bb:cc:dd:ee:ff', 'auto-negotiate' => true)
      expect(content['vlan']['parent']).to match(%r{\A\h{8}-(\h{4}-){3}\h{12}\z})
    end

    it 'orders the activation after the activation of the parent' do
      is_expected.to contain_exec("activate connection after initial config #{content['connection']['uuid']}")
    end

    it { is_expected.not_to contain_networkmanager_link("link of connection #{content['connection']['uuid']}") }
  end

  context 'with the interface_name and the state down' do
    let(:facts) { nm_test_facts('AlmaLinux', '9') }
    let(:params) { { config: {}, state: 'down', interface_name: 'eth0' } }

    it 'shuts the link of the device down after the deactivation, like the other defines' do
      uuid = catalogue.resource('Networkmanager_keyfile', '/etc/NetworkManager/system-connections/fallback0.nmconnection')[:content]['connection']['uuid']
      is_expected.to contain_networkmanager_link("link of connection #{uuid}").with(interface_name: 'eth0', state: 'down')
                                                                              .that_requires("Exec[deactivate connection #{uuid}]")
    end
  end

  context 'with a master that is not a valid id' do
    let(:facts) { nm_test_facts('AlmaLinux', '9') }
    let(:params) { { config: { 'connection' => { 'master' => 'UUID=11111111-2222-3333-4444-555555555555' } } } }

    it { is_expected.to compile.and_raise_error(%r{UUID= prefix}) }
  end

  context 'with a master which is the connection itself' do
    let(:facts) { nm_test_facts('AlmaLinux', '9') }
    let(:params) { { config: { 'connection' => { 'master' => 'fallback0', 'slave-type' => 'bond' } } } }

    # not a dependency cycle: the self reference is ignored by the ordering (NetworkManager refuses such a profile)
    it { is_expected.to compile.with_all_deps }
  end
end
