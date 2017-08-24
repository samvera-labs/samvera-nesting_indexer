require "samvera/nesting_indexer/version"
require 'samvera/nesting_indexer/relationship_reindexer'
require 'samvera/nesting_indexer/repository_reindexer'
require 'samvera/nesting_indexer/configuration'
require 'samvera/nesting_indexer/railtie' if defined?(Rails)

module Samvera
  # Responsible for indexing an object and its related child objects.
  module NestingIndexer
    # This assumes a rather deep graph
    DEFAULT_TIME_TO_LIVE = 15
    # @api public
    # Responsible for reindexing the associated document for the given :pid and the descendants of that :pid.
    # In a perfect world we could reindex the pid as well; But that is for another test.
    #
    # @param pid [String] - The permanent identifier of the object that will be reindexed along with its children.
    # @param time_to_live [Integer] - there to guard against cyclical graphs
    # @return [Boolean] - It was successful
    # @raise Samvera::Exceptions::CycleDetectionError - A potential cycle was detected
    def self.reindex_relationships(pid, time_to_live = DEFAULT_TIME_TO_LIVE)
      RelationshipReindexer.call(pid: pid, time_to_live: time_to_live, adapter: adapter)
      true
    end

    class << self
      # Here because I made a previous declaration that .reindex was part of the
      # public API. Then I decided I didn't want to use that method.
      alias reindex reindex_relationships
    end

    # @api public
    # Responsible for reindexing the entire preservation layer.
    # @param time_to_live [Integer] - there to guard against cyclical graphs
    # @return [Boolean] - It was successful
    # @raise Samvera::Exceptions::CycleDetectionError - A potential cycle was detected
    def self.reindex_all!(time_to_live = DEFAULT_TIME_TO_LIVE)
      # While the RepositoryReindexer is responsible for reindexing everything, I
      # want to inject the lambda that will reindex a single item.
      pid_reindexer = method(:reindex_relationships)
      RepositoryReindexer.call(time_to_live: time_to_live, pid_reindexer: pid_reindexer, adapter: adapter)
      true
    end

    # @api public
    #
    # Contains the Samvera::NestingIndexer configuration information that is referenceable from wit
    # @see Samvera::NestingIndexer::Configuration
    def self.configuration
      @configuration ||= Configuration.new
    end

    # @api public
    #
    # Exposes the data adapter to use for the reindexing process.
    #
    # @see Samvera::NestingIndexer::Adapters::AbstractAdapter
    # @return Object that implementes the Samvera::NestingIndexer::Adapters::AbstractAdapter method interface
    def self.adapter
      configuration.adapter
    end

    # @api public
    #
    # Capture the configuration information
    #
    # @see Samvera::NestingIndexer::Configuration
    # @see .configuration
    # @see Samvera::NestingIndexer::Railtie
    def self.configure(&block)
      @configuration_block = block
      # The Rails load sequence means that some of the configured Targets may
      # not be loaded; As such I am not calling configure! instead relying on
      # Samvera::NestingIndexer::Railtie to handle the configure! call
      configure! unless defined?(Rails)
    end

    # @api private
    def self.configure!
      return false unless @configuration_block.respond_to?(:call)
      @configuration_block.call(configuration)
      @configuration_block = nil
    end
  end
end
