require 'curate/indexer/adapters/abstract_adapter'
require 'curate/indexer/exceptions'

module Curate
  # :nodoc:
  module Indexer
    # @api public
    # Responsible for the configuration of the Curate::Indexer
    class Configuration
      # @api public
      # @return Curate::Indexer::Adapters::AbstractAdapter
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
        "WARNING: You are using the default Curate::Indexer::Adapters::InMemoryAdapter for the Curate::Indexer.adapter.".freeze

      def default_adapter
        $stdout.puts IN_MEMORY_ADAPTER_WARNING_MESSAGE unless defined?(SUPPRESS_MEMORY_ADAPTER_WARNING)
        require 'curate/indexer/adapters/in_memory_adapter'
        Adapters::InMemoryAdapter
      end
    end
    private_constant :Configuration
  end
end
