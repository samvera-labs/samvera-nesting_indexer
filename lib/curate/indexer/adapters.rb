module Curate
  module Indexer
    module Adapters
      # @api public
      # A module that defines the interface of methods required to interact with Curate::Indexer operations
      module AbstractAdapter
        # @api public
        # @param pid [String]
        # @return Curate::Indexer::Document::PreservationDocument
        def self.find_preservation_document_by(*)
          raise NotImplementedError
        end

        # @api public
        # @param pid [String]
        # @return Curate::Indexer::Documents::IndexDocument
        def self.find_index_document_by(*)
          raise NotImplementedError
        end

        # @api public
        # @yield Curate::Indexer::Document::PreservationDocument
        def self.each_preservation_document
          raise NotImplementedError
        end

        # @api public
        # @param pid [String]
        # @yield Curate::Indexer::Documents::IndexDocument
        def self.each_child_document_of(*, &_block)
          raise NotImplementedError
        end

        # @api public
        # @return Curate::Indexer::Documents::IndexDocument
        def self.write_document_attributes_to_index_layer(*)
          raise NotImplementedError
        end
      end
      # @api public
      #
      # Defines the interface for interacting with the InMemory layer. It is a reference
      # implementation that is used throughout tests.
      module InMemoryAdapter
        extend AbstractAdapter
        # @api public
        # @param pid [String]
        # @return Curate::Indexer::Document::PreservationDocument
        def self.find_preservation_document_by(pid)
          Preservation.find(pid)
        end

        # @api public
        # @param pid [String]
        # @return Curate::Indexer::Documents::IndexDocument
        def self.find_index_document_by(pid)
          Index.find(pid)
        end

        # @api public
        # @yield Curate::Indexer::Document::PreservationDocument
        def self.each_preservation_document
          Preservation.find_each { |document| yield(document) }
        end

        # @api public
        # @param pid [String]
        # @yield Curate::Indexer::Documents::IndexDocument
        def self.each_child_document_of(pid, &block)
          Index.each_child_document_of(pid, &block)
        end

        # @api public
        # This is not something that I envision using in the production environment;
        # It is hear to keep the Preservation system isolated and accessible only through interfaces.
        # @return Curate::Indexer::Documents::PreservationDocument
        def self.write_document_attributes_to_preservation_layer(attributes = {})
          Preservation.write_document(attributes)
        end

        # @api public
        # @return Curate::Indexer::Documents::IndexDocument
        def self.write_document_attributes_to_index_layer(attributes = {})
          Index.write_document(attributes)
        end

        # @api private
        def self.clear_cache!
          Preservation.clear_cache!
          Index.clear_cache!
        end
      end
    end
  end
end
