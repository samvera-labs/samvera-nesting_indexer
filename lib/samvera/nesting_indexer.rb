require "samvera/nesting_indexer/version"
require 'samvera/nesting_indexer/relationship_reindexer'
require 'samvera/nesting_indexer/repository_reindexer'
require 'samvera/nesting_indexer/configuration'
require 'samvera/nesting_indexer/documents'
require 'samvera/nesting_indexer/railtie' if defined?(Rails)

module Samvera
  # @api public
  #
  # A container module responsible for exposing public API methods for nested indexing and the
  # underlying configuration to perform that indexing.
  module NestingIndexer
    # @api public
    # Responsible for reindexing the associated document for the given :id and the descendants of that :id.
    # In a perfect world we could reindex the id as well; But that is for another test.
    #
    # @param id [String] - The permanent identifier of the object that will be reindexed along with its children.
    # @param maximum_nesting_depth [Integer] - used to short-circuit overly deep nesting as well as prevent accidental cyclic graphs
    #                                          from creating an infinite loop.
    # @param extent [String] - may be leveraged in adapter to limit the extent of the reindexing of children
    # @return [Boolean] - It was successful
    # @raise Samvera::Exceptions::CycleDetectionError - A possible cycle was detected
    # @raise Samvera::Exceptions::ExceededMaximumNestingDepthError - We exceeded our maximum depth
    # @raise Samvera::Exceptions::DocumentIsItsOwnAncestorError - A document we were about to index appeared to be its own ancestor
    def self.reindex_relationships(id:, maximum_nesting_depth: configuration.maximum_nesting_depth, extent:)
      RelationshipReindexer.call(id: id, maximum_nesting_depth: maximum_nesting_depth, configuration: configuration, extent: extent)
      true
    end

    class << self
      # Here because I made a previous declaration that .reindex was part of the
      # public API. Then I decided I didn't want to use that method.
      alias reindex reindex_relationships
    end

    # @api public
    # Responsible for reindexing the entire preservation layer.
    # @param maximum_nesting_depth [Integer] - there to guard against cyclic graphs
    # @param extent [String] - for reindex_all, should result in full reindexing... leveraged in adapter to limit the extent of the reindexing of children
    # @return [Boolean] - It was successful
    # @raise Samvera::Exceptions::ReindexingError - There was a problem reindexing the graph.
    def self.reindex_all!(maximum_nesting_depth: configuration.maximum_nesting_depth, extent:)
      # While the RepositoryReindexer is responsible for reindexing everything, I
      # want to inject the lambda that will reindex a single item.
      id_reindexer = method(:reindex_relationships)
      RepositoryReindexer.call(maximum_nesting_depth: maximum_nesting_depth, id_reindexer: id_reindexer, configuration: configuration, extent: extent)
      true
    end

    # @api public
    #
    # Contains the Samvera::NestingIndexer configuration information that is referenceable from wit
    # @see Samvera::NestingIndexer::Configuration
    def self.configuration
      @configuration ||= Configuration.new
    end

    class << self
      alias config configuration
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
