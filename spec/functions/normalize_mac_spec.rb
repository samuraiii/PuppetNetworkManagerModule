# frozen_string_literal: true

require 'spec_helper'

describe 'networkmanager::normalize_mac' do
  it { is_expected.to run.with_params('aa:bb:cc:dd:ee:ff').and_return('aa:bb:cc:dd:ee:ff') }
  it { is_expected.to run.with_params('AA:BB:CC:DD:EE:FF').and_return('aa:bb:cc:dd:ee:ff') }
  it { is_expected.to run.with_params('AA-BB-CC-DD-EE-FF').and_return('aa:bb:cc:dd:ee:ff') }
  it { is_expected.to run.with_params('00:11:22:33:44:55').and_return('00:11:22:33:44:55') }
  it { is_expected.to run.with_params(Array.new(20) { |i| format('%02X', i) }.join('-')).and_return(Array.new(20) { |i| format('%02x', i) }.join(':')) }
  it { is_expected.to run.with_params('aabb.ccdd.eeff').and_raise_error(ArgumentError) }
end

describe 'networkmanager::connection_duid' do
  let(:pre_condition) { 'include networkmanager' }
  let(:facts) { nm_test_facts('AlmaLinux', '9') }

  it { is_expected.to run.with_params('AA:BB:CC:DD:EE:FF').and_return('00:03:00:01:aa:bb:cc:dd:ee:ff') }
  it { is_expected.to run.with_params('AA-BB-CC-DD-EE-FF').and_return('00:03:00:01:aa:bb:cc:dd:ee:ff') }
end
