# frozen_string_literal: true

require 'spec_helper'

describe 'networkmanager::mac_address_settings' do
  it { is_expected.to run.with_params('ethernet', nil).and_return({}) }
  it { is_expected.to run.with_params('ethernet', 'aa:bb:cc:dd:ee:ff').and_return({ 'ethernet' => { 'mac-address' => 'aa:bb:cc:dd:ee:ff' } }) }
  it { is_expected.to run.with_params('802-3-ethernet', 'aa:bb:cc:dd:ee:ff').and_return({ 'ethernet' => { 'mac-address' => 'aa:bb:cc:dd:ee:ff' } }) }
  it { is_expected.to run.with_params('wifi', 'aa:bb:cc:dd:ee:ff').and_return({ '802-11-wireless' => { 'mac-address' => 'aa:bb:cc:dd:ee:ff' } }) }
  it { is_expected.to run.with_params('ethernet', 'AA-BB-CC-DD-EE-FF').and_return({ 'ethernet' => { 'mac-address' => 'aa:bb:cc:dd:ee:ff' } }) }
  context 'with the 20 bytes of InfiniBand' do
    let(:mac) { '00:11:22:33:44:55:66:77:88:99:aa:bb:cc:dd:ee:ff:00:11:22:33' }

    it { is_expected.to run.with_params('ethernet', mac.upcase).and_return({ 'ethernet' => { 'mac-address' => mac } }) }
  end

  it { is_expected.to run.with_params('bond', 'aa:bb:cc:dd:ee:ff').and_raise_error(%r{can not be set for the connection type 'bond'}) }
  it { is_expected.to run.with_params('bond', nil).and_return({}) }
end

describe 'networkmanager::forbid_uuid_override' do
  it { is_expected.to run.with_params({}, 'eth0').and_return(nil) }
  it { is_expected.to run.with_params({ 'connection' => { 'autoconnect' => false } }, 'eth0').and_return(nil) }
  it { is_expected.to run.with_params({ 'connection' => { 'uuid' => 'x' } }, 'eth0').and_raise_error(%r{connection 'eth0' can not set the connection\.uuid}) }

  %w[id interface-name master slave-type].each do |key|
    it { is_expected.to run.with_params({ 'connection' => { key => 'x' } }, 'eth0').and_raise_error(%r{can not set the connection\.#{key}}) }
  end
end
