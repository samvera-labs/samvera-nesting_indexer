SUPPRESS_MEMORY_ADAPTER_WARNING = true
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'coverage_helper'
require 'samvera/nesting_indexer'
require 'rspec/its'

Samvera::NestingIndexer.configure do |config|
  config.logger = Logger.new('/dev/null') unless ENV['VERBOSE'] # Remove all the chatter!
end
