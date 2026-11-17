# frozen_string_literal: true

require 'spec_helper'

describe 'Networkmanager::IPV6_ADDRESSES' do
  it { is_expected.to allow_value('2001:db8::5/64') }
  it { is_expected.to allow_value(['2001:db8::5/64', 'fd00::5/64']) }
  it { is_expected.to allow_value('2001:db8::5/64;fd00::5/64') }
  it { is_expected.to allow_value('2001:db8::5/64;fd00::5/64;') }
  it { is_expected.to allow_value('2001:db8::5/64;') }
  it { is_expected.to allow_value('2001:db8::5/128') }

  it { is_expected.to allow_value('::/0') }
  it { is_expected.to allow_value('::/128') }
  it { is_expected.to allow_value(['::1/128']) }

  it { is_expected.not_to allow_value('::') }
  it { is_expected.not_to allow_value('2001:db8::5') }
  it { is_expected.not_to allow_value('2001:db8::5/64;fd00::5') }
  it { is_expected.not_to allow_value('2001:db8::5/129') }
  it { is_expected.not_to allow_value('2001:db8::5/999') }
  it { is_expected.not_to allow_value(['2001:db8::5']) }
  it { is_expected.not_to allow_value([]) }
end
