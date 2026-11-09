# frozen_string_literal: true

require 'spec_helper'

describe 'Networkmanager::Port_type' do
  %w[bond bridge ovs-bridge ovs-port team vrf].each do |type|
    it { is_expected.to allow_value(type) }
  end

  it { is_expected.not_to allow_value('ethernet') }
  it { is_expected.not_to allow_value('') }
  it { is_expected.not_to allow_value('Bond') }
  it { is_expected.not_to allow_value(nil) }
end
