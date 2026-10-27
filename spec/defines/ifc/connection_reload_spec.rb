# frozen_string_literal: true

require 'spec_helper'

# networkmanager::reload is a private class, it is included by the connections (rspec-puppet can not declare it
# on its own), so it is tested through a connection
describe 'networkmanager::ifc::connection' do
  let(:title) { 'eth0' }
  let(:params) { { ipv6_method: 'ignore', ipv4_method: 'auto' } }

  each_test_os do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to contain_class('networkmanager::reload') }
      # the activation execs are virtual resources of this catalog, realized by the class (not exported)
      it { is_expected.to have_exec_resource_count(2) }

      it 'runs the activation as root through the shell' do
        execs = catalogue.resources.select { |r| 'Exec' == r.type && r.title.start_with?('activate connection') }
        expect(execs.map { |r| [r[:user], r[:provider]] }.uniq).to eq([%w[root shell]])
      end
    end
  end
end
