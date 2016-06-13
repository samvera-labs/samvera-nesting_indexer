require 'curate/indexer/storage_module'
require 'curate/indexer/documents'

module Curate
  # :nodoc:
  module Indexer
    # @api private
    #
    # A module responsible for containing the "preservation interface" logic.
    # In the case of CurateND, there will need to be an adapter to get a Fedora
    # object coerced into a Curate::Indexer::Preservation::Document
    module Preservation
      def self.find(pid, *)
        MemoryStorage.find(pid)
      end

      def self.find_each(*, &block)
        MemoryStorage.find_each(&block)
      end

      def self.clear_cache!
        MemoryStorage.clear_cache!
      end

      def self.write_document(attributes = {})
        Documents::PreservationDocument.new(attributes).tap do |doc|
          MemoryStorage.write(doc)
        end
      end

      # :nodoc:
      module MemoryStorage
        extend StorageModule
      end
      private_constant :MemoryStorage
    end
    private_constant :Preservation
  end
end
