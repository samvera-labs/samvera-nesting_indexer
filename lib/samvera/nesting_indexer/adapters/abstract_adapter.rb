module Samvera
  module NestingIndexer
    module Adapters
      # @api public
      # A module that defines the interface of methods required to interact with Samvera::NestingIndexer operations
      # rubocop:disable Lint/UnusedMethodArgument
      module AbstractAdapter
        # @api public
        # @param id [String]
        # @return [Samvera::NestingIndexer::Document::PreservationDocument]
        def self.find_preservation_document_by(id:)
          raise NotImplementedError
        end

        # @api public
        # @param id [String]
        # @return [Samvera::NestingIndexer::Documents::IndexDocument]
        def self.find_index_document_by(id:)
          raise NotImplementedError
        end

        # @api public
        # @since 0.7.0
        # @yieldparam id [String] The `id` of the preservation document
        # @yieldparam parent_ids [String] The ids of the parent objects of this presevation document
        def self.each_perservation_document_id_and_parent_ids(&block)
          raise NotImplementedError
        end

        # @api public
        # @since 0.7.0
        # @param id [String] The `id` of the preservation document
        # @return [Array<String>] The parent ids of the given preservation document
        def self.find_preservation_parent_ids_for(id:)
          raise NotImplementedError
        end

        # @api public
        # @param document [Samvera::NestingIndexer::Documents::IndexDocument]
        # @yield [Samvera::NestingIndexer::Documents::IndexDocument]
        def self.each_child_document_of(document:, &block)
          raise NotImplementedError
        end

        # @api public
        # @see README.md
        # @param id [String]
        # @param parent_ids [Array<String>]
        # @param ancestors [Array<String>]
        # @param pathnames [Array<String>]
        # @return Hash - the attributes written to the indexing layer
        def self.write_document_attributes_to_index_layer(id:, parent_ids:, ancestors:, pathnames:)
          raise NotImplementedError
        end
      end
      # rubocop:enable Lint/UnusedMethodArgument
    end
  end
end
