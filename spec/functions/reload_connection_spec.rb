# frozen_string_literal: true

require 'spec_helper'
require 'open3'

describe 'networkmanager::reload_connection' do
  let(:uuid) { '11111111-2222-3333-4444-555555555555' }

  %w[up down].each do |state|
    it "reloads the connections and sets the connection #{state} after the D-Bus service appeared" do
      command = subject.execute(uuid, state)
      expect(command).to end_with("&& /usr/bin/nmcli connection reload && /usr/bin/nmcli connection #{state} #{uuid}")
      expect(command).to include('/usr/bin/gdbus introspect --system --dest org.freedesktop.NetworkManager')
    end
  end

  it 'limits the wait for the D-Bus service' do
    expect(subject.execute(uuid, 'up')).to match(%r{test 60 -le "\$\{n\}".*exit 1})
  end

  it 'is a valid shell command' do
    _out, err, status = Open3.capture3('/bin/sh', '-n', '-c', subject.execute(uuid, 'up'))
    expect([err, status.success?]).to eq(['', true])
  end

  it { is_expected.to run.with_params('not-a-uuid', 'up').and_raise_error(ArgumentError) }
end
