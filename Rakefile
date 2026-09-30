# frozen_string_literal: true

begin
  require 'puppetlabs_spec_helper/rake_tasks'
  require 'puppet-syntax/tasks/puppet-syntax'

  PuppetLint.configuration.send('disable_relative')
rescue LoadError
  # Tested without puppetlabs_spec_helper (OpenVox 8.24 and newer, 9): only the fixtures are prepared here
  require 'fileutils'
  require 'json'
  require 'yaml'

  desc 'Prepare the fixtures: the modules of .fixtures.yml (if missing) and the link to this module'
  task :spec_prep do
    modules = File.join('spec', 'fixtures', 'modules')
    FileUtils.mkdir_p(modules)
    fixtures = File.file?('.fixtures.yml') ? YAML.safe_load(File.read('.fixtures.yml'))['fixtures'] : {}
    (fixtures['repositories'] || {}).each do |name, source|
      target = File.join(modules, name)
      next if File.exist?(target)

      repo, ref = source.is_a?(Hash) ? source.values_at('repo', 'ref') : [source, nil]
      sh(*['git', 'clone', '--depth', '1', *(ref ? ['--branch', ref] : []), repo, target])
    end
    link = File.join(modules, JSON.parse(File.read('metadata.json'))['name'].split(%r{[-/]}).last)
    FileUtils.ln_s(File.expand_path('.'), link) unless File.exist?(link)
  end
end
