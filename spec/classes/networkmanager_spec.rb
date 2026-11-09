# frozen_string_literal: true

require 'spec_helper'

describe 'networkmanager' do
  each_test_os do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to contain_class('networkmanager::os') }
      it { is_expected.to contain_class('networkmanager::install') }
      it { is_expected.to contain_class('networkmanager::config') }
      it { is_expected.to contain_class('networkmanager::service') }
      it { expect(keyfile_text('/etc/NetworkManager/NetworkManager.conf')).to match(%r{^\[main\]$}) }
      it { is_expected.to contain_service('NetworkManager').with_ensure('running').with_enable(true) }

      case os_facts['os']['family']
      when 'Debian'
        it { is_expected.to contain_package('network-manager') }
      when 'RedHat'
        it { is_expected.to contain_package('NetworkManager') }
      when 'Archlinux'
        it { is_expected.to contain_package('networkmanager') }
      when 'Gentoo'
        it { is_expected.to contain_package('net-misc/networkmanager') }
      end
    end
  end

  context 'with install_package => false' do
    let(:facts) { nm_test_facts('AlmaLinux', '9') }
    let(:params) { { install_package: false } }

    it { is_expected.to compile.with_all_deps }
    it { is_expected.not_to contain_package('NetworkManager') }
  end

  context 'with wait_online => false' do
    let(:facts) { nm_test_facts('AlmaLinux', '9') }
    let(:params) { { wait_online: false } }

    it { is_expected.to contain_service('NetworkManager-wait-online').with_ensure('stopped').with_enable(false) }
  end

  context 'without the os.family fact' do
    let(:facts) { nm_test_facts('AlmaLinux', '9').merge('os' => { 'name' => 'Odd' }) }

    it { is_expected.to compile.and_raise_error(%r{OS family '' is not supported}) }

    context 'with ignore_unsupported_os' do
      let(:params) { { ignore_unsupported_os: true } }

      it { is_expected.to compile.with_all_deps }
    end
  end

  context 'with an unsupported OS family' do
    let(:facts) { nm_test_facts('Solaris', '11', 'Solaris') }

    it { is_expected.to compile.and_raise_error(%r{OS family 'Solaris' is not supported}) }
  end
end

describe 'networkmanager' do
  let(:facts) { nm_test_facts('AlmaLinux', '9') }

  context 'with an unsupported OS family and ignore_unsupported_os' do
    let(:facts) { nm_test_facts('Solaris', '11', 'Solaris') }
    let(:params) { { ignore_unsupported_os: true } }

    it { is_expected.to compile.with_all_deps }
    it { is_expected.to have_package_resource_count(0) }
    it { is_expected.to contain_service('NetworkManager') }
  end

  context 'with an unsupported OS family and the install_package => false' do
    let(:facts) { nm_test_facts('Solaris', '11', 'Solaris') }
    let(:params) { { install_package: false } }

    it 'still fails, ignore_unsupported_os is the explicit choice' do
      is_expected.to compile.and_raise_error(%r{ignore_unsupported_os})
    end
  end

  context 'with the defaults' do
    it { is_expected.to contain_package('NetworkManager').with_ensure('present').that_notifies('Service[NetworkManager]') }
    it 'contains the subclasses' do
      %w[Os Install Config Service].each do |name|
        expect(catalogue.adjacent(catalogue.resource('Class', 'Networkmanager'))).to include(catalogue.resource('Class', "Networkmanager::#{name}"))
      end
    end
  end

  context 'with the order of the subclasses' do
    let(:facts) { nm_test_facts('AlmaLinux', '9') }

    it { is_expected.to contain_class('networkmanager::install').that_requires('Class[networkmanager::os]') }
    it { is_expected.to contain_class('networkmanager::config').that_requires('Class[networkmanager::install]') }
    it { is_expected.to contain_class('networkmanager::service').that_requires('Class[networkmanager::config]') }
  end

  context 'with a version' do
    let(:params) { { version: '1.46.0-1.el9' } }

    it { is_expected.to contain_package('NetworkManager').with_ensure('1.46.0-1.el9') }
  end

  context 'with an empty version' do
    let(:params) { { version: '' } }

    it { is_expected.to compile.and_raise_error(%r{version}) }
  end

  context 'without the fqdn fact' do
    let(:facts) { nm_test_facts('AlmaLinux', '9').merge('networking' => {}) }

    it 'uses the certname of the node' do
      is_expected.to compile.with_all_deps
    end
  end

  context 'without the no_auto_default' do
    it { expect(keyfile_text('/etc/NetworkManager/NetworkManager.conf')).not_to include('no-auto-default') }
  end

  context 'with no_auto_default => true' do
    let(:params) { { no_auto_default: true } }

    it { expect(keyfile_text('/etc/NetworkManager/NetworkManager.conf')).to match(%r{^no-auto-default=\*$}) }
  end

  context 'with a string no_auto_default' do
    let(:params) { { no_auto_default: 'eth0' } }

    it { is_expected.to compile.and_raise_error(%r{no_auto_default}) }
  end

  context 'with the unmanaged devices written for NetworkManager' do
    let(:params) { { unmanaged_devices: ['AA-BB-CC-DD-EE-FF', '00:11:22:33:44:55', 'docker*'] } }

    it 'normalizes the MAC addresses' do
      expect(keyfile_text('/etc/NetworkManager/NetworkManager.conf')).to match(%r{^unmanaged-devices=mac:aa:bb:cc:dd:ee:ff;mac:00:11:22:33:44:55;interface-name:docker\*$})
    end
  end
end

describe 'networkmanager' do
  let(:facts) { nm_test_facts('AlmaLinux', '9') }

  ['00:03:00', '00:03:00:01:02', 'zz:03:00:01', "00:03:00:01\n00:03:00:01"].each do |prefix|
    context "with the duid_prefix #{prefix.inspect}" do
      let(:params) { { duid_prefix: prefix } }

      it { is_expected.to compile.and_raise_error(%r{duid_prefix}) }
    end
  end
end
