# frozen_string_literal: true

require 'spec_helper'

describe 'networkmanager::config' do
  let(:pre_condition) { 'include networkmanager' }

  each_test_os do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }
    end
  end

  context 'with the defaults' do
    let(:facts) { nm_test_facts('AlmaLinux', '9') }

    it { is_expected.to contain_networkmanager_keyfile('/etc/NetworkManager/NetworkManager.conf').with_show_diff(true).with_secret_keys([]).that_notifies('Class[networkmanager::service]') }
    it { is_expected.to contain_networkmanager_keyfile_dir('/etc/NetworkManager/system-connections').with_purge(false) }
    it { is_expected.to contain_file('/etc/NetworkManager/system-connections').with_ensure('directory').without_purge }
  end

  context 'with erase_unmanaged_keyfiles' do
    let(:facts) { nm_test_facts('AlmaLinux', '9') }
    let(:pre_condition) { 'class { "networkmanager": erase_unmanaged_keyfiles => true }' }

    it { is_expected.to contain_networkmanager_keyfile_dir('/etc/NetworkManager/system-connections').with_purge(true) }
  end

  context 'with connections_dir' do
    let(:facts) { nm_test_facts('AlmaLinux', '9') }
    let(:pre_condition) { 'class { "networkmanager": connections_dir => "/srv/nm", erase_unmanaged_keyfiles => true }' }

    it { is_expected.to contain_file('/srv/nm').with_ensure('directory') }
    it { is_expected.to contain_networkmanager_keyfile_dir('/srv/nm').with_purge(true) }
  end

  context 'with show_diff => false and secret_keys' do
    let(:facts) { nm_test_facts('AlmaLinux', '9') }
    let(:pre_condition) { 'class { "networkmanager": show_diff => false, secret_keys => ["my-key"] }' }

    it { is_expected.to contain_networkmanager_keyfile('/etc/NetworkManager/NetworkManager.conf').with_show_diff(false).with_secret_keys(['my-key']) }
  end

  context 'with the unmanaged devices and plugins' do
    let(:facts) { nm_test_facts('AlmaLinux', '9') }
    let(:pre_condition) { 'class { "networkmanager": unmanaged_devices => ["docker*", "veth?", "00:11:22:33:44:55"], plugins => ["keyfile", "ifcfg-rh"] }' }

    it { is_expected.to compile.with_all_deps }
  end

  context 'with a separator in an unmanaged device' do
    let(:facts) { nm_test_facts('AlmaLinux', '9') }
    let(:pre_condition) { 'class { "networkmanager": unmanaged_devices => ["eth0;interface-name:br0"] }' }

    it { is_expected.to compile.and_raise_error(%r{unmanaged_devices}) }
  end

  context 'with a separator in a plugin' do
    let(:facts) { nm_test_facts('AlmaLinux', '9') }
    let(:pre_condition) { 'class { "networkmanager": plugins => ["keyfile,evil"] }' }

    it { is_expected.to compile.and_raise_error(%r{plugins}) }
  end

  context 'with use_internal_resolv_conf => false' do
    let(:facts) { nm_test_facts('AlmaLinux', '9') }
    let(:pre_condition) { 'class { "networkmanager": use_internal_resolv_conf => false }' }

    it { is_expected.to contain_exec('replace the resolv.conf link by a file').with_provider('shell').with_user('root').that_comes_before('File[/etc/resolv.conf]') }
    it { is_expected.to contain_exec('replace the resolv.conf link by a file').with_onlyif(['/usr/bin/test -L /etc/resolv.conf', '/usr/bin/test -e /etc/resolv.conf']) }
    it { is_expected.to contain_file('/etc/resolv.conf').with_ensure('file').with_replace(false).with_mode('0644') }
  end

  context 'with use_internal_resolv_conf => stub' do
    let(:facts) { nm_test_facts('AlmaLinux', '9') }
    let(:pre_condition) { 'class { "networkmanager": use_internal_resolv_conf => "stub" }' }

    it { is_expected.to contain_file('/etc/resolv.conf').with_ensure('link').with_target('/run/NetworkManager/resolv.conf') }
    it { is_expected.not_to contain_exec('replace the resolv.conf link by a file') }
  end
end
