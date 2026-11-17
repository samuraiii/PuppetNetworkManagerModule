# frozen_string_literal: true

require 'spec_helper'

describe 'networkmanager::connection_keyfile_manage' do
  let(:facts) { nm_test_facts('AlmaLinux', '9') }
  let(:pre_condition) { 'include networkmanager' }
  let(:title) { 'eth0' }
  let(:params) { { content: { 'connection' => { 'id' => 'eth0' } } } }

  it { is_expected.to compile.and_raise_error(%r{is private}) }
end
