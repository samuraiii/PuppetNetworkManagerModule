# frozen_string_literal: true

require 'spec_helper'

describe 'networkmanager::service' do
  let(:pre_condition) { 'include networkmanager' }

  each_test_os do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }
    end
  end

  context 'with the defaults' do
    let(:facts) { nm_test_facts('AlmaLinux', '9') }

    it { is_expected.to contain_service('NetworkManager').with_ensure('running').with_enable(true) }
    it { is_expected.to contain_service('NetworkManager-wait-online').with_ensure('running').with_enable(true) }
  end

  context 'with wait_online => false' do
    let(:facts) { nm_test_facts('AlmaLinux', '9') }
    let(:pre_condition) { 'class { "networkmanager": wait_online => false }' }

    it { is_expected.to contain_service('NetworkManager').with_ensure('running').with_enable(true) }
    it { is_expected.to contain_service('NetworkManager-wait-online').with_ensure('stopped').with_enable(false) }
  end

  context 'with wait_online => false without systemd' do
    let(:facts) { nm_test_facts('Gentoo', '2').merge('service_provider' => 'gentoo') }
    let(:pre_condition) { 'class { "networkmanager": wait_online => false }' }

    # no unit to switch off, the unknown service is not managed
    it { is_expected.to contain_service('NetworkManager') }
    it { is_expected.not_to contain_service('NetworkManager-wait-online') }
  end
end
