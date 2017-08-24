require 'samvera/indexer/adapters/abstract_adapter'
require 'samvera/indexer/exceptions'

module Samvera
  # :nodoc:
  module Indexer
    # @api public
    # Responsible for the configuration of the Samvera::Indexer
    class Configuration
      # @api public
      # @return Samvera::Indexer::Adapters::AbstractAdapter
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
        "WARNING: You are using the default Samvera::Indexer::Adapters::InMemoryAdapter for the Samvera::Indexer.adapter.".freeze

      def default_adapter
        $stdout.puts IN_MEMORY_ADAPTER_WARNING_MESSAGE unless defined?(SUPPRESS_MEMORY_ADAPTER_WARNING)
        require 'samvera/indexer/adapters/in_memory_adapter'
        Adapters::InMemoryAdapter
      end
    end
    private_constant :Configuration
  end
end
