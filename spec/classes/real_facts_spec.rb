# frozen_string_literal: true

require 'spec_helper'

# The other specs use the generated facts of nm_test_facts(). These use the real facts of facterdb, so the way
# Facter reports the operating system family (eg. the Amazon Linux and the derivatives of Red Hat) is tested too:
# every operating system release listed in metadata.json which facterdb knows has to be supported by the module.
describe 'networkmanager' do
  on_supported_os.each do |os, os_facts|
    context "on #{os} with the facts of facterdb" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to contain_service('NetworkManager') }

      # the name of the package of the family, which the unsupported OS handling skips
      package = { 'Debian' => 'network-manager', 'RedHat' => 'NetworkManager', 'Archlinux' => 'networkmanager', 'Gentoo' => 'net-misc/networkmanager' }[os_facts[:os]['family']]
      it { is_expected.to contain_package(package) }
    end
  end

  it 'finds at least one operating system of metadata.json in facterdb' do
    expect(on_supported_os).not_to be_empty
  end
end
