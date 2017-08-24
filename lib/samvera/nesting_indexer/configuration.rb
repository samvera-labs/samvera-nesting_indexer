require 'samvera/nesting_indexer/adapters/abstract_adapter'
require 'samvera/nesting_indexer/exceptions'

module Samvera
  # :nodoc:
  module NestingIndexer
    # @api public
    # Responsible for the configuration of the Samvera::NestingIndexer
    class Configuration
      DEFAULT_TIME_TO_LIVE = 15

      def initialize(adapter: default_adapter, time_to_live: DEFAULT_TIME_TO_LIVE)
        self.adapter = adapter
        self.time_to_live = time_to_live
      end

      attr_reader :time_to_live

      def time_to_live=(input)
        @time_to_live = input.to_i
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
