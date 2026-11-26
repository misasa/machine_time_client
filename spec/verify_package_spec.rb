require 'spec_helper'
require 'bundler'
require 'rubygems/package'
require 'open3'
require 'rbconfig'
require 'tmpdir'
require 'fileutils'

RSpec.describe 'installed package verification' do
  let(:root) { File.expand_path('..', __dir__) }

  around do |example|
    Dir.mktmpdir('machine-time-package-spec-') do |directory|
      @directory = directory
      @checkout = File.join(directory, 'checkout')
      FileUtils.mkdir_p(@checkout)
      %w[lib script README.md LICENSE.txt machine_time_client.gemspec].each do |path|
        FileUtils.cp_r(File.join(root, path), @checkout)
      end
      example.run
    end
  end

  def build
    Dir.chdir(@checkout) do
      spec = Gem::Specification.load(File.join(root, 'machine_time_client.gemspec')).dup
      yield spec if block_given?
      Gem::Package.build(spec, true)
      File.join(@checkout, spec.file_name)
    end
  end

  def verify(archive, environment = {})
    Open3.capture3(environment, RbConfig.ruby,
                  File.join(@checkout, 'script/verify_package.rb'), archive, chdir: root)
  end

  it 'loads the installed library outside the checkout and Bundler' do
    stdout, stderr, status = verify(build)
    expect(status.success?).to be(true), stderr
    expect(stdout).to include('PASS archive and installed library')
  end

  {
    'wrong license' => [lambda { |spec| spec.license = 'MIT' }, /license/],
    'wrong Ruby floor' => [lambda { |spec| spec.required_ruby_version = '>= 2.7' }, /Ruby floor/],
    'wrong version' => [lambda { |spec| spec.version = '9.9.9' }, /version/],
    'missing runtime file' => [lambda { |spec| spec.files -= ['lib/machine_time_client/session.rb'] }, /packaged files/],
    'development file' => [lambda { |spec| spec.files += ['script/verify_release.rb'] }, /packaged files/]
  }.each do |description, (change, error)|
    it "rejects #{description}" do
      _, stderr, status = verify(build(&change))
      expect(status.success?).to be(false)
      expect(stderr).to match(error)
    end
  end

  it 'verifies with a Git-sourced runtime dependency outside Bundler' do
    dependency = Gem.loaded_specs.fetch('logger')
    checkout = File.join(@directory, 'logger')
    FileUtils.cp_r(dependency.full_gem_path, checkout)
    git_spec = dependency.dup
    git_spec.files = Dir.chdir(checkout) { Dir['lib/**/*.rb'] }
    File.write(File.join(checkout, 'logger.gemspec'), git_spec.to_ruby)
    [%w[init -q], %w[add .],
     ['-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
      '-c', 'commit.gpgsign=false', 'commit', '-qm', 'Fixture']].each do |args|
      _, stderr, status = Open3.capture3('git', *args, chdir: checkout)
      expect(status.success?).to be(true), stderr
    end
    gemfile = File.join(@directory, 'Gemfile')
    File.write(gemfile, <<~GEMFILE)
      source 'https://rubygems.org'
      gemspec path: #{@checkout.inspect}
      gem 'logger', git: #{checkout.inspect}
    GEMFILE
    archive = build
    bundle = Gem.bin_path('bundler', 'bundle')
    environment = {'BUNDLE_GEMFILE' => gemfile, 'BUNDLE_IGNORE_CONFIG' => '1'}
    Bundler.with_unbundled_env do
      _, stderr, status = Open3.capture3(environment, RbConfig.ruby, bundle, 'install', '--local')
      expect(status.success?).to be(true), stderr
      stdout, stderr, status = verify(archive, environment)
      expect(status.success?).to be(true), stderr
      expect(stdout).to include('PASS archive and installed library')
    end
  end

  it 'rejects renamed archives' do
    archive = build
    renamed = File.join(@directory, 'renamed.gem')
    FileUtils.cp(archive, renamed)
    _, stderr, status = verify(renamed)
    expect(status.success?).to be(false)
    expect(stderr).to include('filename')
  end

  it 'rejects archive contents that differ from the checkout' do
    archive = build
    File.open(File.join(@checkout, 'lib/machine_time_client.rb'), 'a') { |file| file.puts '# changed' }
    _, stderr, status = verify(archive)
    expect(status.success?).to be(false)
    expect(stderr).to include('Archive differs from source')
  end

  it 'rejects corrupt archives' do
    archive = build
    File.binwrite(archive, 'not a gem')
    _, _, status = verify(archive)
    expect(status.success?).to be(false)
  end
end
