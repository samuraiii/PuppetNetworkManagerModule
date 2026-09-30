# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

describe Puppet::Type.type(:networkmanager_keyfile_dir) do
  let(:dir) { Dir.mktmpdir }
  let(:catalog) { Puppet::Resource::Catalog.new }

  before do
    %w[kept.nmconnection stray.nmconnection other].each { |name| File.write(File.join(dir, name), '') }
    kept = Puppet::Type.type(:networkmanager_keyfile).new(path: File.join(dir, 'kept.nmconnection'), content: {})
    catalog.add_resource(kept)
  end

  after { FileUtils.remove_entry(dir) }

  it 'requires an absolute path' do
    expect { described_class.new(path: 'relative') }.to raise_error(Puppet::Error, %r{absolute})
  end

  it 'generates nothing without the purge' do
    resource = described_class.new(path: dir, catalog: catalog)
    expect(resource.generate).to eq([])
  end

  it 'generates the removal of the files which are not in the catalog' do
    resource = described_class.new(path: dir, purge: true, catalog: catalog)
    generated = resource.generate
    expect(generated.map { |r| r[:path] }).to eq([File.join(dir, 'other'), File.join(dir, 'stray.nmconnection')])
    expect(generated.map { |r| r[:ensure] }.uniq).to eq([:absent])
  end
end
