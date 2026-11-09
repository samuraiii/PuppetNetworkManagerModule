# frozen_string_literal: true

require 'spec_helper'

describe 'networkmanager::port_settings' do
  let(:pre_condition) { 'include networkmanager' }
  let(:facts) { nm_test_facts('AlmaLinux', '9') }
  let(:uuid) { '11111111-2222-3333-4444-555555555555' }

  it { is_expected.to run.with_params(nil, nil, 'eth0').and_return({}) }
  it { is_expected.to run.with_params(nil, 'bridge', 'eth0').and_return({}) }
  it { is_expected.to run.with_params(uuid, 'bridge', 'eth0').and_return({ 'master' => uuid, 'slave-type' => 'bridge' }) }
  it { is_expected.to run.with_params(uuid, nil, 'bond0').and_raise_error(%r{connection 'bond0' has the master .* but no slave_type}) }
  it { is_expected.to run.with_params(uuid, 'nonsense', 'eth0').and_raise_error(ArgumentError) }

  it { is_expected.to run.with_params('bond0', 'bond', 'bond0').and_raise_error(%r{master 'bond0' of the connection 'bond0' is the connection itself}) }

  it 'converts the id of the master to the UUID which the connection of that id has' do
    expect(subject.execute('br0', 'bridge', 'bond0')['master']).to eq('ffaa1255-1cfc-5fc3-b3ec-329ea787b099')
  end

  it { is_expected.to run.with_params("UUID=#{uuid}", 'bridge', 'eth0').and_raise_error(%r{UUID= prefix}) }
end
