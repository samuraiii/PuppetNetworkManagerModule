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
end
