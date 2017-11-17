module Samvera
  module NestingIndexer
    module Exceptions
      class RuntimeError < ::RuntimeError
      end

      # There is some kind configuration error.
      class ConfigurationError < RuntimeError
      end

      # Danger, the SolrKey may not be configured correctly.
      class SolrKeyConfigurationError < ConfigurationError
        attr_reader :name, :config
        def initialize(name:, config:)
          @name = name
          @config = config
          super "Expected #{name.inspect} to be set in Config #{config.inspect}"
        end
      end

      # Raised when we have a misconfigured adapter
      class AdapterConfigurationError < ConfigurationError
        attr_reader :expected_methods
        def initialize(object, expected_methods)
          @expected_methods = expected_methods
          super "Expected #{object.inspect} to implement #{expected_methods.inspect} methods"
        end
      end

      # Raised when we may have detected a cycle within the graph
      class CycleDetectionError < RuntimeError
        attr_reader :id
        def initialize(id:)
          @id = id
          super to_s
        end

        def to_s
          "Possible graph cycle discovered related to ID=#{id.inspect}."
        end
      end

      # Raised when we have exceeded the time to live constraint
      # @see Samvera::NestingIndexer::Configuration.maximum_nesting_depth
      class ExceededMaximumNestingDepthError < CycleDetectionError
        def to_s
          "Exceeded maximum nesting depth while indexing ID=#{id.inspect}."
        end
      end

      # Raised when we encounter a document that is to be indexed as its own ancestor.
      class DocumentIsItsOwnAncestorError < CycleDetectionError
        attr_reader :pathnames
        def initialize(id:, pathnames:)
          super(id: id)
          @pathnames = pathnames
        end

        def to_s
          "Document with ID=#{id.inspect} is marked as its own ancestor based on the given pathnames: #{pathnames.inspect}."
        end
      end
      # A wrapper exception that includes the original exception and the id
      class ReindexingError < RuntimeError
        attr_reader :id, :original_exception
        def initialize(id, original_exception)
          @id = id
          @original_exception = original_exception
          super "ReindexingError on ID=#{id.inspect}\n\t#{original_exception}"
        end
      end
    end
  end
end
