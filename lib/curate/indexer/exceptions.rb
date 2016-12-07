module Curate
  module Indexer
    module Exceptions
      class RuntimeError < ::RuntimeError
      end

      # Raised when we have a misconfigured adapter
      class AdapterConfigurationError < RuntimeError
        attr_reader :expected_methods
        def initialize(object, expected_methods)
          @expected_methods = expected_methods
          super "Expected #{object.inspect} to implement #{expected_methods.inspect} methods"
        end
      end

      # Raised when we may have detected a cycle within the graph
      class CycleDetectionError < RuntimeError
        attr_reader :pid
        def initialize(pid)
          @pid = pid
          super "Possible graph cycle discovered related to PID=#{pid}."
        end
      end
      # A wrapper exception that includes the original exception and the pid
      class ReindexingError < RuntimeError
        attr_reader :pid, :original_exception
        def initialize(pid, original_exception)
          @pid = pid
          @original_exception = original_exception
          super "Error PID=#{pid} - #{original_exception}"
        end
      end
    end
  end
end
