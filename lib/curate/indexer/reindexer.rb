module Curate
  # Responsible for the indexing strategy of related objects
  module Indexer
    # Coordinates the reindexing of the entire direct relationship graph
    class Reindexer
      def initialize(requested_pid:, max_level:)
        self.requested_pid = requested_pid
        self.max_level = max_level
        @document_to_reindex = Processing.find_or_create_processing_document_for(pid: requested_pid, level: 0)
        @rebuilder = Index.new_rebuilder(requested_for: document_to_reindex)
        @queue = Queue.new
      end
      attr_reader :requested_pid, :max_level, :rebuilder, :document_to_reindex, :queue

      def reindex
        document = document_to_reindex
        while document
          document.member_of.each do |member_of_pid|
            reindex_relation(document: document, member_of_pid: member_of_pid)
          end
          document = queue.dequeue
        end
        rebuilder.rebuild_and_return_requested_for
      end

      private

      attr_writer :requested_pid, :max_level

      def reindex_relation(document:, member_of_pid:)
        next_level = document.level + 1
        guard_max_level_achieved!(next_level: next_level)
        member_of_document = Processing.find_or_create_processing_document_for(pid: member_of_pid, level: next_level)
        rebuilder.associate(document: document, member_of_document: member_of_document)
        queue.enqueue(member_of_document)
      end

      def guard_max_level_achieved!(next_level:)
        return true if next_level < max_level
        raise(
          ReindexingReachedMaxLevelError,
          requested_pid: requested_pid,
          visited_pids: rebuilder.visited_pids,
          max_level: max_level
        )
      end
    end
  end
end
