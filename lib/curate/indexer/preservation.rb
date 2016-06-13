require 'curate/indexer/storage_module'

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
        Document.new(attributes).write
      end

      # @api private
      #
      # A simplified document that reflects the necessary attributes for re-indexing
      # the children of Fedora objects.
      class Document
        def initialize(keywords = {})
          @pid = keywords.fetch(:pid).to_s
          @parent_pids = Array(keywords.fetch(:parent_pids))
        end
        attr_reader :pid, :parent_pids

        def write
          MemoryStorage.write(self)
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
