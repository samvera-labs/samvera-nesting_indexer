module Curate
  module Indexer
    module Exceptions
      class RuntimeError < ::RuntimeError
      end
      # Raised when we may have detected a cycle within the graph
      class CycleDetectionError < RuntimeError
        attr_reader :pid
        def initialize(pid)
          @pid = pid
          super "Possible graph cycle discovered related to PID:#{pid}."
        end
      end
    end
  end
end
