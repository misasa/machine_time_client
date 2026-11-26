#!/usr/bin/env ruby
# Run under Bundler. Install only this archive; reuse precisely resolved dependencies.
require 'bundler'
require 'rubygems/package'
require 'rbconfig'
require 'open3'
require 'tmpdir'
require 'fileutils'
require 'digest'
require_relative '../lib/machine_time_client/version'

root = File.expand_path('..', __dir__)
archive = File.expand_path(ARGV.fetch(0) { File.join(root, 'pkg', "machine_time_client-#{MachineTimeClient::VERSION}.gem") })
package = Gem::Package.new(archive)
raise 'Invalid gem archive' unless package.verify
spec = package.spec
raise 'Package version differs from source' unless spec.version.to_s == MachineTimeClient::VERSION
raise 'Archive filename differs from gemspec' unless File.basename(archive) == spec.file_name
raise 'Wrong package name' unless spec.name == 'machine_time_client'
expected_files = Dir.chdir(root) { %w[README.md LICENSE.txt] + Dir['lib/**/*.rb'] }
raise 'Unexpected or missing packaged files' unless package.contents.sort == expected_files.sort
raise 'Wrong executable metadata' unless spec.executables.empty?
raise 'Wrong license metadata' unless spec.licenses == ['GPL-3.0-or-later']
raise 'Wrong Ruby floor' unless spec.required_ruby_version.to_s == '>= 2.6.0'

# A new gem home contains only the resolved dependency versions. No access to
# unrelated installed gems, and no download or change to the user's gem home.
resolved = Bundler.load.specs.to_a
names = spec.runtime_dependencies.map(&:name)
dependencies = []
until names.empty?
  name = names.shift
  next if dependencies.any? { |dependency| dependency.name == name }
  dependency = resolved.find { |candidate| candidate.name == name }
  raise "Missing resolved runtime dependency: #{name}" unless dependency
  dependencies << dependency
  names.concat(dependency.runtime_dependencies.map(&:name))
end
Dir.mktmpdir('machine_time_client-package-') do |directory|
  extracted = File.join(directory, 'archive')
  package.extract_files(extracted)
  expected_files.each do |path|
    raise "Archive differs from source: #{path}" unless Digest::SHA256.file(File.join(extracted, path)).hexdigest == Digest::SHA256.file(File.join(root, path)).hexdigest
  end
  home = File.join(directory, 'gems')
  FileUtils.mkdir_p([File.join(home, 'gems'), File.join(home, 'specifications')])
  dependencies.each do |dependency|
    FileUtils.ln_s(dependency.full_gem_path, File.join(home, 'gems', dependency.full_name))
    File.write(File.join(home, 'specifications', "#{dependency.full_name}.gemspec"), dependency.to_ruby)
    if dependency.extensions.any?
      target = File.join(home, 'extensions', Gem::Platform.local.to_s, Gem.extension_api_version, dependency.full_name)
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.ln_s(dependency.extension_dir, target)
    end
  end

  File.write(File.join(directory, '.godigorc'), "---\nuri_machine: https://machine.invalid/machine/\nmachine: TEST\n")
  environment = {'HOME' => directory, 'GEM_HOME' => home, 'GEM_PATH' => home, 'RUBYLIB' => nil, 'RUBYOPT' => nil}
  execute = lambda do |*arguments|
    stdout, stderr, status = Open3.capture3(environment, RbConfig.ruby, *arguments, chdir: directory)
    raise "Command failed (#{status.exitstatus}): #{arguments.inspect}\n#{stdout}\n#{stderr}" unless status.success?
    stdout
  end
  Bundler.with_unbundled_env do
    execute.call('-rrubygems/gem_runner', '-e', 'Gem::GemRunner.new.run(ARGV)', '--',
                 'install', '--local', '--no-document', '--ignore-dependencies', archive)
    check = <<~'RUBY'
      require 'machine_time_client'
      spec = Gem.loaded_specs.fetch('machine_time_client')
      abort 'Wrong installed version' unless MachineTimeClient::VERSION == ARGV.fetch(0)
      abort 'Wrong installation directory' unless File.realpath(spec.base_dir) == File.realpath(ENV.fetch('GEM_HOME'))
      feature = $LOADED_FEATURES.find { |path| path.end_with?('/lib/machine_time_client.rb') }
      abort 'Loaded source instead of installed gem' unless feature == File.join(spec.full_gem_path, 'lib/machine_time_client.rb')
      machine = MachineTimeClient::Machine.new(id: 12, name: 'Installed machine')
      abort 'Installed resource failed' unless machine.name == 'Installed machine'
      abort 'Installed route failed' unless MachineTimeClient::Machine.element_path(12) == '/machine/machines/12.json'
      abort 'Installed configuration failed' unless MachineTimeClient.machine_name == 'TEST'
      abort 'Installed session failed' unless MachineTimeClient::Session.new(id: 1).id == 1
      puts MachineTimeClient::VERSION
    RUBY
    execute.call('-e', check, MachineTimeClient::VERSION)
  end
end
puts "PASS archive and installed library: #{File.basename(archive)} (Ruby #{RUBY_VERSION})"
