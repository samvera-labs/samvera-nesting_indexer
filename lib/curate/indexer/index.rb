require 'curate/indexer/storage_module'
require 'curate/indexer/documents'

module Curate
  # :nodoc:
  module Indexer
    # @api private
    #
    # An abstract representation of the underlying index service. In the case of
    # CurateND this is an abstraction of Solr.
    module Index
      def self.clear_cache!
        Storage.clear_cache!
      end

      def self.find(pid)
        Storage.find(pid)
      end

      def self.each_child_document_of(document, &block)
        Storage.find_children_of_pid(document.pid).each(&block)
      end

      def self.write_document(attributes = {})
        Documents::IndexDocument.new(attributes).tap { |doc| Storage.write(doc) }
      end

      # :nodoc:
      module Storage
        extend StorageModule
        def self.find_children_of_pid(pid)
          cache.values.select { |document| document.parent_pids.include?(pid) }
        end
      end
      private_constant :Storage
    end
    private_constant :Index
  end
end
