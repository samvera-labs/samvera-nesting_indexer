module Curate
  # Establishing namespace
  module Indexer
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
      # @param options [Hash]
      # @option options [Integer] pid_reindexer Curate::Indexer.method(:reindex_relationships) Responsible for reindexing a single object
      # @option options [Integer] time_to_live Curate::Indexer::TIME_TO_LIVE to detect cycles in the graph
      # @option options [Curate::Indexer::Adapters::AbstractAdapter] adapter
      # @return Curate::Indexer::RepositoryReindexer
      def self.call(*args)
        new(*args).call
      end

      def initialize(options = {})
        @max_time_to_live = options.fetch(:time_to_live).to_i
        @pid_reindexer = options.fetch(:pid_reindexer)
        @adapter = options.fetch(:adapter)
        @processed_pids = []
      end

      # @todo Would it make sense to leverage an each_preservation_pid instead?
      def call
        @adapter.each_preservation_document { |document| recursive_reindex(document, max_time_to_live) }
      end

      private

      attr_reader :max_time_to_live, :processed_pids, :pid_reindexer

      # When we find a document, reindex it if it doesn't have a parent. If it has a parent, reindex the parent first.
      #
      # Given that we are attempting to reindex the parents before we reindex a document, we can't rely on
      # the reindex time_to_live but instead must have a separate time to live.
      #
      # The reindexing process assumes that an object's parents have been indexed; Thus we need to
      # walk up the parent graph to reindex the parents before we start on the child.
      def recursive_reindex(document, time_to_live = max_time_to_live)
        return true if processed_pids.include?(document.pid)
        raise Exceptions::CycleDetectionError, document.pid if time_to_live <= 0
        document.parent_pids.each do |parent_pid|
          parent_document = @adapter.find_preservation_document_by(parent_pid)
          recursive_reindex(parent_document, time_to_live - 1)
        end
        reindex_a_pid(document.pid)
      end

      def reindex_a_pid(pid)
        pid_reindexer.call(pid)
        processed_pids << pid
      rescue StandardError => e
        raise Exceptions::ReindexingError.new(pid, e)
      end
    end
    private_constant :RepositoryReindexer
  end
end
