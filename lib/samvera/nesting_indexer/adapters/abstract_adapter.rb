module Samvera
  module NestingIndexer
    module Adapters
      # @api public
      # A module that defines the interface of methods required to interact with Samvera::NestingIndexer operations
      # rubocop:disable Lint/UnusedMethodArgument
      module AbstractAdapter
        # @api public
        # @param id [String]
        # @return Samvera::NestingIndexer::Document::PreservationDocument
        def self.find_preservation_document_by(id:)
          raise NotImplementedError
        end

        # @api public
        # @param id [String]
        # @return Samvera::NestingIndexer::Documents::IndexDocument
        def self.find_index_document_by(id:)
          raise NotImplementedError
        end

        # @api public
        # @yield Samvera::NestingIndexer::Document::PreservationDocument
        def self.each_preservation_document(&block)
          raise NotImplementedError
        end

        # @api public
        # @param document [Samvera::NestingIndexer::Documents::IndexDocument]
        # @yield Samvera::NestingIndexer::Documents::IndexDocument
        def self.each_child_document_of(document, &block)
          raise NotImplementedError
        end

        # @api public
        # @return Hash - the attributes written to the indexing layer
        def self.write_document_attributes_to_index_layer(attributes = {})
          raise NotImplementedError
        end
      end
      # rubocop:enable Lint/UnusedMethodArgument
    end
  end
end
