# frozen_string_literal: true

require 'spec_helper'

describe 'Networkmanager::Interface_name' do
  it { is_expected.to allow_value('eth0') }
  it { is_expected.to allow_value('br-0') }
  it { is_expected.to allow_value('bond.100') }
  it { is_expected.to allow_value('0abc') }
  it { is_expected.to allow_value('a' * 15) }

  it { is_expected.to allow_value('a') }
  it { is_expected.to allow_value('ab') }
  it { is_expected.to allow_value('allx') }
  it { is_expected.to allow_value('All') }

  it { is_expected.not_to allow_value('') }
  it { is_expected.not_to allow_value('all') }
  it { is_expected.not_to allow_value('default') }
  it { is_expected.not_to allow_value('a' * 16) }
  it { is_expected.not_to allow_value('-batch') }
  it { is_expected.not_to allow_value('.eth0') }
  it { is_expected.not_to allow_value('a/b') }
  it { is_expected.not_to allow_value('a:b') }
  it { is_expected.not_to allow_value('eth*') }
  it { is_expected.not_to allow_value('eth?') }
  it { is_expected.not_to allow_value('eth[0]') }
  it { is_expected.not_to allow_value('a\\b') }
  it { is_expected.not_to allow_value('e th') }
  it { is_expected.not_to allow_value("eth0\n[ipv4]") }
  it { is_expected.not_to allow_value('ethé0') }
end
