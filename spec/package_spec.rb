require 'spec_helper'

RSpec.describe 'machine_time_client gem package' do
  let(:root) { File.expand_path('..', __dir__) }
  let(:specification) do
    Dir.chdir(root) { Gem::Specification.load('machine_time_client.gemspec') }
  end

  it 'declares the license already granted by LICENSE.txt' do
    expect(specification.licenses).to eq(['GPL-3.0-or-later'])
  end

  {
    '2.5.9' => false,
    '2.6.0' => true,
    '2.6.10' => true,
    '2.7.8' => true,
    '3.4.0' => true,
    '4.0.9' => true
  }.each do |version, allowed|
    it "#{allowed ? 'allows' : 'excludes'} installation on Ruby #{version}" do
      requirement = specification.required_ruby_version
      expect(requirement.satisfied_by?(Gem::Version.new(version))).to be(allowed)
    end
  end

  it 'does not install any commands' do
    expect(specification.executables).to be_empty
  end

  it 'packages runtime code, README and license without development files' do
    runtime = Dir.chdir(root) { Dir['lib/**/*.rb'] }
    expect(specification.files.sort).to eq((runtime + %w[README.md LICENSE.txt]).sort)
  end
end
