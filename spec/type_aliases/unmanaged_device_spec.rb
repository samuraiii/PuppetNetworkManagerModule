# frozen_string_literal: true

require 'spec_helper'

describe 'Networkmanager::Unmanaged_device' do
  it { is_expected.to allow_value('eth0') }
  it { is_expected.to allow_value('docker*') }
  it { is_expected.to allow_value('veth?') }
  it { is_expected.to allow_value('00:11:22:33:44:55') }

  it { is_expected.not_to allow_value('') }
  it { is_expected.not_to allow_value('eth0;br0') }
  it { is_expected.not_to allow_value('interface-name:br0') }
  it { is_expected.not_to allow_value('a/b') }
  it { is_expected.not_to allow_value('e th') }
  it { is_expected.not_to allow_value("eth0\n") }
  it { is_expected.not_to allow_value('a' * 16) }
end
