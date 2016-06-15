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

      def default_adapter
        require 'curate/indexer/in_memory_adapter'
        InMemoryAdapter
      end
    end
    private_constant :Configuration
  end
end
