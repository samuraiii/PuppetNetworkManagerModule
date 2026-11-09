# frozen_string_literal: true

require 'spec_helper'

describe 'networkmanager::connection_uuid' do
  let(:pre_condition) { 'class networkmanager { $sys_id = "test" }  include networkmanager' }

  it { is_expected.to run.with_params('12345678-1234-1234-1234-123456789012').and_return('12345678-1234-1234-1234-123456789012') }
  it { is_expected.to run.with_params('eth0').and_return(%r{\A\h{8}-(\h{4}-){3}\h{12}\z}) }

  it 'does not take a multi-line string with an uuid on the first line as an uuid' do
    value = "12345678-1234-1234-1234-123456789012\ntouch /tmp/x"
    is_expected.to run.with_params(value).and_return(%r{\A\h{8}-(\h{4}-){3}\h{12}\z})
  end

  it { is_expected.to run.with_params('UUID=12345678-1234-1234-1234-123456789012').and_raise_error(%r{UUID= prefix}) }
  it { is_expected.to run.with_params(nil).and_raise_error(ArgumentError) }

  context 'with the uuid_seed' do
    let(:pre_condition) { 'class { "networkmanager": uuid_seed => "seed" }' }

    ['a.example.com', 'b.example.com'].each do |fqdn|
      context "on #{fqdn}" do
        let(:facts) { nm_test_facts('AlmaLinux', '9').merge('networking' => { 'fqdn' => fqdn }) }

        it { is_expected.to run.with_params('eth0').and_return('9267dd03-761c-5986-8b37-84599441d264') }
      end
    end
  end

  context 'without the uuid_seed' do
    let(:pre_condition) { 'include networkmanager' }
    let(:facts) { nm_test_facts('AlmaLinux', '9') }

    it 'depends on the node' do
      expect(subject.execute('eth0')).not_to eq(subject.execute('eth1'))
    end
  end
end
