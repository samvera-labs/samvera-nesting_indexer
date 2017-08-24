require 'samvera/nesting_indexer/adapters/abstract_adapter'
require 'samvera/nesting_indexer/exceptions'

module Samvera
  # :nodoc:
  module NestingIndexer
    # @api public
    # Responsible for the configuration of the Samvera::NestingIndexer
    class Configuration
      DEFAULT_MAXIMUM_NESTING_DEPTH = 15

      def initialize(adapter: default_adapter, maximum_nesting_depth: DEFAULT_MAXIMUM_NESTING_DEPTH)
        self.adapter = adapter
        self.maximum_nesting_depth = maximum_nesting_depth
      end

      attr_reader :maximum_nesting_depth

      def maximum_nesting_depth=(input)
        @maximum_nesting_depth = input.to_i
      end

      # @api public
      # @return Samvera::NestingIndexer::Adapters::AbstractAdapter
      def adapter
        @adapter || default_adapter
      end

      # @raise AdapterConfigurationError if the given adapter does not implement the correct interface
      def adapter=(object)
        object_methods = object.methods
        adapter_methods = Adapters::AbstractAdapter.methods(false)
        # Making sure that the adapter methods are all available in the object_methods
        raise Exceptions::AdapterConfigurationError.new(object, adapter_methods) unless adapter_methods & object_methods == adapter_methods
        @adapter = object
      end

      private

      IN_MEMORY_ADAPTER_WARNING_MESSAGE =
        "WARNING: You are using the default Samvera::NestingIndexer::Adapters::InMemoryAdapter for the Samvera::NestingIndexer.adapter.".freeze

      def default_adapter
        $stdout.puts IN_MEMORY_ADAPTER_WARNING_MESSAGE unless defined?(SUPPRESS_MEMORY_ADAPTER_WARNING)
        require 'samvera/nesting_indexer/adapters/in_memory_adapter'
        Adapters::InMemoryAdapter
      end
    end
    private_constant :Configuration
  end
end
