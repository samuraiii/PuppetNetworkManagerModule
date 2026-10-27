# frozen_string_literal: true

require 'spec_helper'

describe 'Networkmanager::Plugin' do
  it { is_expected.to allow_value('keyfile') }
  it { is_expected.to allow_value('ifcfg-rh') }

  it { is_expected.not_to allow_value('') }
  it { is_expected.not_to allow_value('keyfile,evil') }
  it { is_expected.not_to allow_value('Keyfile') }
  it { is_expected.not_to allow_value("keyfile\n") }
end
