module Curate
  module Indexer
    # An assistive class in the breadth first search.
    class Queue
      def initialize
        @queue = []
      end

      def enqueue(object)
        @queue << object
      end

      def dequeue
        @queue.shift
      end
    end
  end
end
