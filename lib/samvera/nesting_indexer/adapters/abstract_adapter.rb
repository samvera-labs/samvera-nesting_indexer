module Samvera
  module NestingIndexer
    module Adapters
      # @api public
      # A module that defines the interface of methods required to interact with Samvera::NestingIndexer operations
      module AbstractAdapter
        # @api public
        # @param pid [String]
        # @return Samvera::NestingIndexer::Document::PreservationDocument
        def self.find_preservation_document_by(*)
          raise NotImplementedError
        end

        # @api public
        # @param pid [String]
        # @return Samvera::NestingIndexer::Documents::IndexDocument
        def self.find_index_document_by(*)
          raise NotImplementedError
        end

        # @api public
        # @yield Samvera::NestingIndexer::Document::PreservationDocument
        def self.each_preservation_document
          raise NotImplementedError
        end

        # @api public
        # @param document [Samvera::NestingIndexer::Documents::IndexDocument]
        # @yield Samvera::NestingIndexer::Documents::IndexDocument
        def self.each_child_document_of(*, &_block)
          raise NotImplementedError
        end

        # @api public
        # @return Hash - the attributes written to the indexing layer
        def self.write_document_attributes_to_index_layer(*)
          raise NotImplementedError
        end
      end
    end
  end
end
