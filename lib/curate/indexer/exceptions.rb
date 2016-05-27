module Curate
  # Responsible for the indexing strategy of related objects
  module Indexer
    # Namespacing for common errors
    class RuntimeError < RuntimeError
    end
    # An exception thrown when a possible cycle is detected in the graph.
    class ReindexingReachedMaxLevelError < RuntimeError
      attr_accessor :requested_pid, :visited_pids, :max_level
      def initialize(requested_pid:, visited_pids:, max_level:)
        self.requested_pid = requested_pid
        self.visited_pids = visited_pids
        self.max_level = max_level
        super("ERROR: Reindexing reached level #{max_level} on PID:#{requested_pid}. Possible graph cycle detected.")
      end
    end
  end
end
