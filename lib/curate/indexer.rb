require "curate/indexer/version"
require 'curate/indexer/relationship_reindexer'
require 'curate/indexer/repository_reindexer'
require 'curate/indexer/configuration'

module Curate
  # Responsible for performign the indexing of an object and its related child objects.
  module Indexer
    # This assumes a rather deep graph
    DEFAULT_TIME_TO_LIVE = 15
    # @api public
    # Responsible for reindexing the associated document for the given :pid and the descendants of that :pid.
    # In a perfect world we could reindex the pid as well; But that is for another test.
    #
    # @param pid [String] - The permanent identifier of the object that will be reindexed along with its children.
    # @param time_to_live [Integer] - there to guard against cyclical graphs
    # @return [Boolean] - It was successful
    # @raise Curate::Exceptions::CycleDetectionError - A potential cycle was detected
    def self.reindex_relationships(pid, time_to_live = DEFAULT_TIME_TO_LIVE)
      RelationshipReindexer.call(pid: pid, time_to_live: time_to_live, adapter: configuration.adapter)
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
    # @raise Curate::Exceptions::CycleDetectionError - A potential cycle was detected
    def self.reindex_all!(time_to_live = DEFAULT_TIME_TO_LIVE)
      RepositoryReindexer.call(time_to_live: time_to_live, pid_reindexer: method(:reindex_relationships), adapter: configuration.adapter)
      true
    end

    # Contains the Curate::Indexer configuration information that is referenceable from wit
    # @see Curate::Indexer::Configuration
    def self.configuration
      @configuration ||= Configuration.new
    end

    # @api public
    def self.adapter
      configuration.adapter
    end

    # @api public
    # @see Curate::Indexer::Configuration
    # @see .configuration
    def self.configure(&block)
      @configuration_block = block
      configure!
      # # The Rails load sequence means that some of the configured Targets may
      # # not be loaded; As such I am not calling configure! instead relying on
      # # Curate::Indexer::Railtie to handle the configure! call
      # configure! unless defined?(Rails)
    end

    # @api public
    def self.configure!
      return false unless @configuration_block.respond_to?(:call)
      @configuration_block.call(configuration)
      @configuration_block = nil
    end
  end
end
