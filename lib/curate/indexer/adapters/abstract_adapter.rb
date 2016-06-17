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
    end
  end
end
