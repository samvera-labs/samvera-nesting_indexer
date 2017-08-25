module Samvera
  # Establishing namespace
  module NestingIndexer
    # Responsible for reindexing the entire repository
    # @api private
    # @note There is cycle detection logic for walking the graph prior to attempting relationship re-indexing
    class RepositoryReindexer
      # @api private
      #
      # A convenience method to reindex all documents.
      #
      # @note This could crush your system as it will loop through ALL the documents
      #
      # @see #initialize
      # @return Samvera::NestingIndexer::RepositoryReindexer
      def self.call(*args)
        new(*args).call
      end

      # @param id_reindexer [#call] Samvera::NestingIndexer.method(:reindex_relationships) Responsible for reindexing a single object
      # @param maximum_nesting_depth [Integer] detect cycles in the graph
      # @param adapter [Samvera::NestingIndexer::Adapters::AbstractAdapter] Conforms to the Samvera::NestingIndexer::Adapters::AbstractAdapter interface
      def initialize(maximum_nesting_depth:, id_reindexer:, adapter:)
        @max_maximum_nesting_depth = maximum_nesting_depth.to_i
        @id_reindexer = id_reindexer
        @adapter = adapter
        @processed_ids = []
      end

      # @todo Would it make sense to leverage an each_preservation_id instead?
      def call
        @adapter.each_preservation_document { |document| recursive_reindex(document, max_maximum_nesting_depth) }
      end

      private

      attr_reader :max_maximum_nesting_depth, :processed_ids, :id_reindexer

      # When we find a document, reindex it if it doesn't have a parent. If it has a parent, reindex the parent first.
      #
      # Given that we are attempting to reindex the parents before we reindex a document, we can't rely on
      # the reindex maximum_nesting_depth but instead must have a separate time to live.
      #
      # The reindexing process assumes that an object's parents have been indexed; Thus we need to
      # walk up the parent graph to reindex the parents before we start on the child.
      def recursive_reindex(document, maximum_nesting_depth = max_maximum_nesting_depth)
        return true if processed_ids.include?(document.id)
        raise Exceptions::CycleDetectionError, document.id if maximum_nesting_depth <= 0
        document.parent_ids.each do |parent_id|
          parent_document = @adapter.find_preservation_document_by(id: parent_id)
          recursive_reindex(parent_document, maximum_nesting_depth - 1)
        end
        reindex_an_id(document.id)
      end

      def reindex_an_id(id)
        id_reindexer.call(id: id)
        processed_ids << id
      rescue StandardError => e
        raise Exceptions::ReindexingError.new(id, e)
      end
    end
    private_constant :RepositoryReindexer
  end
end
