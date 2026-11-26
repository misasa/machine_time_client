require 'tmpdir'
require 'fileutils'

# Load the library with an isolated configuration before its resource classes
# read the site. Never read or write the developer's ~/.godigorc.
spec_config_dir = Dir.mktmpdir('machine-time-spec-config-')
spec_original_home = ENV['HOME']
ENV['HOME'] = spec_config_dir
File.write(File.join(spec_config_dir, '.godigorc'), "---\nuri_machine: https://machine.invalid/machine/\nmachine: TEST\n")
at_exit do
  ENV['HOME'] = spec_original_home
  FileUtils.remove_entry(spec_config_dir)
end

require 'machine_time_client'

#MachineTimeClient.config = {:uri_machine => "http://database.misasa.okayama-u.ac.jp/machine/", :machine => "JXA-8800"}

class Output
  def messages
    @messages ||= []
  end
  
  def puts(message)
    messages << message
  end

  def print(message)
    messages << message
  end
end


RSpec::Matchers.define :exit_with_code do |code|
	def supports_block_expectations?
		true
	end

	actual = nil
	match do |block|
		begin
			block.call
		rescue SystemExit => e
			actual = e.status
		end
		actual && actual == code
	end

	failure_message do |block|
		"expected block to call exit(#{code}) but exit" + (actual.nil? ? " not called" : "(#{actual}) was called" )
	end

	failure_message_when_negated do |block|
		"expected block not to call exit(#{code})"
	end

	description do
		"expect block to call exit(#{code})"
	end

end

RSpec.configure do |config|
  config.mock_with :rspec do |c|
    c.syntax = [:should, :expect]
  end
  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end
end
