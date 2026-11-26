# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'machine_time_client/version'

Gem::Specification.new do |spec|
  spec.name          = "machine_time_client"
  spec.version       = MachineTimeClient::VERSION
  spec.authors       = ["Yusuke Yachi"]
  spec.email         = ["yusuke.yachi@gmail.com"]
  spec.summary       = %q{Ruby client for the MachineTime REST API.}
  spec.description   = %q{Access MachineTime machines and sessions through ActiveResource.}
  spec.homepage      = "https://github.com/misasa/machine_time_client"
  spec.license       = "GPL-3.0-or-later"
  spec.required_ruby_version = ">= 2.6.0"

  spec.files         = Dir["lib/**/*.rb"] + %w[README.md LICENSE.txt]
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'activeresource', '>= 5.1.1'
  # ActiveSupport 6.1 relies on concurrent-ruby loading Logger on Ruby 2.6.
  spec.add_runtime_dependency 'concurrent-ruby', '~> 1.3', '< 1.3.5'
  spec.add_runtime_dependency 'logger'
  spec.add_runtime_dependency 'ostruct'

  spec.add_development_dependency "bundler", ">= 2.4"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.13"
end
