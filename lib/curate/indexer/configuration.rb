module Curate
  # :nodoc:
  module Indexer
    # Responsible for the configuration of the Curate::Indexer
    class Configuration
      def adapter
        @adapter || default_adapter
      end
      # TODO: Should we guard against a bad adapter?
      attr_writer :adapter

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
