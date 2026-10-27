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
    expect(generated.map { |r| r[:path] }).to eq([File.join(dir, 'stray.nmconnection')])
    expect(generated.map { |r| r[:ensure] }.uniq).to eq([:absent])
  end

  it 'leaves the files which are not keyfiles alone' do
    resource = described_class.new(path: dir, purge: true, catalog: catalog)
    expect(resource.generate.map { |r| r[:path] }).not_to include(File.join(dir, 'other'))
  end

  it 'recognizes the managed keyfile when the directory has a trailing slash' do
    resource = described_class.new(path: "#{dir}/", purge: true, catalog: catalog)
    expect(resource.generate.map { |r| r[:path] }).to eq([File.join(dir, 'stray.nmconnection')])
  end

  it 'recognizes the managed keyfile when its path has a double slash' do
    catalog.add_resource(Puppet::Type.type(:networkmanager_keyfile).new(path: "#{dir}//stray.nmconnection", content: {}))
    resource = described_class.new(path: dir, purge: true, catalog: catalog)
    expect(resource.generate).to eq([])
  end

  it 'generates nothing for a directory which does not exist' do
    resource = described_class.new(path: File.join(dir, 'missing'), purge: true, catalog: catalog)
    expect(resource.generate).to eq([])
  end

  context 'with glob characters in the path of the directory' do
    let(:globdir) { File.join(dir, 'a[b]*') }

    before do
      Dir.mkdir(globdir)
      File.write(File.join(globdir, 'x.nmconnection'), '')
    end

    it 'lists the directory literally' do
      resource = described_class.new(path: globdir, purge: true, catalog: catalog)
      expect(resource.generate.map { |r| r[:path] }).to eq([File.join(globdir, 'x.nmconnection')])
    end
  end
end
