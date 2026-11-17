# frozen_string_literal: true

require 'spec_helper'

describe 'Networkmanager::Connection_id' do
  it { is_expected.to allow_value('eth0') }
  it { is_expected.to allow_value('Wired connection 1') }
  it { is_expected.to allow_value('bond-0.100_a~!@%^&*()+=') }

  it { is_expected.to allow_value('a.b') }
  it { is_expected.to allow_value('eth0.') }

  it { is_expected.not_to allow_value('') }
  it { is_expected.not_to allow_value('.hidden') }
  it { is_expected.not_to allow_value('...') }
  it { is_expected.not_to allow_value('../../etc/cron.d/x') }
  it { is_expected.not_to allow_value('a/b') }
  it { is_expected.not_to allow_value('a\\b') }
  it { is_expected.not_to allow_value("eth0\n[vpn]") }
  it { is_expected.not_to allow_value("eth0\t") }
  it { is_expected.not_to allow_value("eth0\0") }
  it { is_expected.not_to allow_value('ethé0') }
end
