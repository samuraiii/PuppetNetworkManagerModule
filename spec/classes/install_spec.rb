# frozen_string_literal: true

require 'spec_helper'

describe 'networkmanager::install' do
  let(:pre_condition) { 'include networkmanager' }

  each_test_os do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }
    end
  end
end

describe 'networkmanager::install' do
  let(:facts) { nm_test_facts('Debian', '12') }

  context 'with the defaults' do
    let(:pre_condition) { 'include networkmanager' }

    it { is_expected.to contain_package('network-manager').with_ensure('present').that_notifies('Service[NetworkManager]') }
  end

  context 'with a version, the package is changed to it and the daemon restarted' do
    let(:pre_condition) { 'class { "networkmanager": version => "1.42.4-1" }' }

    it { is_expected.to contain_package('network-manager').with_ensure('1.42.4-1').that_notifies('Service[NetworkManager]') }
  end

  context 'with install_package => false' do
    let(:pre_condition) { 'class { "networkmanager": install_package => false }' }

    it { is_expected.not_to contain_package('NetworkManager') }
  end
end
