SUPPRESS_MEMORY_ADAPTER_WARNING = true
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'coverage_helper'
require 'samvera/nesting_indexer'
require 'rspec/its'

Samvera::NestingIndexer.configure do |config|
  config.logger = Logger.new('/dev/null') unless ENV['VERBOSE'] # Remove all the chatter!
end

RSpec.configure do |config|
  config.before(:suite) do
    ENV['SKIP_ACTIVE_SUPPORT_DEPRECATION'] = '1'
  end
  config.after(:suite) do
    STDOUT.puts "\n" + "-" * 80 + "\nSemantic Version Messages:\n" + "-" * 80 + "\n"
    Samvera::NestingIndexer.semantic_version_messages.each do |message|
      STDOUT.puts message
    end
    STDOUT.puts "-" * 80 + "\n"
  end
end
