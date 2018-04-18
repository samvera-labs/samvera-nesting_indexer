require 'samvera/nesting_indexer/adapters/abstract_adapter'
require 'samvera/nesting_indexer/documents'

module Samvera
  module NestingIndexer
    module Adapters
      # @api private
      #
      # Defines the interface for interacting with the InMemory layer. It is a reference
      # implementation that is used throughout tests.
      module InMemoryAdapter
        extend AbstractAdapter
        # @api private
        # @param id [String]
        # @return Samvera::NestingIndexer::Document::PreservationDocument
        def self.find_preservation_document_by(id:)
          Preservation.find(id)
        end

        # @api private
        # @param id [String]
        # @return [Samvera::NestingIndexer::Documents::IndexDocument]
        def self.find_index_document_by(id:)
          Index.find(id)
        end

        # @api private
        # @yieldparam id [String] The `id` of the preservation document
        # @yieldparam parent_ids [String] The ids of the parent objects of this presevation document
        def self.each_perservation_document_id_and_parent_ids(&block)
          Preservation.find_each do |document|
            block.call(document.id, document.parent_ids)
          end
        end

        def self.find_preservation_parent_ids_for(id:)
          Preservation.find(id).parent_ids
        end

        # @api private
        # @param document [Samvera::NestingIndexer::Documents::IndexDocument]
        # @param extent [String] passed into adapter from reindex_relationships call
        # @yield [Samvera::NestingIndexer::Documents::IndexDocument]
        # rubocop:disable Lint/UnusedMethodArgument
        def self.each_child_document_of(document:, extent:, &block)
          Index.each_child_document_of(document: document, extent: "full", &block)
        end
        # rubocop:enable Lint/UnusedMethodArgument

        # @api private
        # This is not something that I envision using in the production environment;
        # It is hear to keep the Preservation system isolated and accessible only through interfaces.
        # @param attributes [Hash]
        # @return [Samvera::NestingIndexer::Documents::PreservationDocument]
        def self.write_document_attributes_to_preservation_layer(attributes)
          Preservation.write_document(attributes)
        end

        # @api private
        # @see README.md
        # @param nesting_document [Samvera::NestingIndexer::Documents::IndexDocument]
        def self.write_nesting_document_to_index_layer(nesting_document:)
          Index.write_to_storage(nesting_document)
        end

        # @api private
        def self.clear_cache!
          Preservation.clear_cache!
          Index.clear_cache!
        end

        # @api private
        # A convenience method for testing
        def self.each_index_document(&block)
          Index.each_index_document(&block)
        end

        # @api private
        #
        # A module mixin to expose rudimentary read/write capabilities
        #
        # @example
        #   module Foo
        #     extend Samvera::NestingIndexer::StorageModule
        #   end
        module StorageModule
          def write(doc)
            cache[doc.id] = doc
          end

          def find(id)
            cache.fetch(id.to_s)
          end

          def find_each
            cache.each_value { |document| yield(document) }
          end

          def clear_cache!
            @cache = {}
          end

          def cache
            @cache ||= {}
          end
          private :cache
        end

        # @api private
        #
        # A module responsible for containing the "preservation interface" logic.
        # In the case of CurateND, there will need to be an adapter to get a Fedora
        # object coerced into a Samvera::NestingIndexer::Preservation::Document
        module Preservation
          def self.find(id, *)
            MemoryStorage.find(id)
          end

          def self.find_each(*, &block)
            MemoryStorage.find_each(&block)
          end

          def self.clear_cache!
            MemoryStorage.clear_cache!
          end

          def self.write_document(**kargs)
            Documents::PreservationDocument.new(**kargs).tap do |doc|
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

        # @api private
        #
        # An abstract representation of the underlying index service. In the case of
        # CurateND this is an abstraction of Solr.
        module Index
          def self.clear_cache!
            Storage.clear_cache!
          end

          def self.find(id)
            Storage.find(id)
          end

          def self.each_index_document(&block)
            Storage.find_each(&block)
          end

          # rubocop:disable Lint/UnusedMethodArgument
          def self.each_child_document_of(document:, extent: nil, &block)
            Storage.find_children_of_id(document.id).each(&block)
          end
          # rubocop:enable Lint/UnusedMethodArgument

          def self.write_to_storage(doc)
            Storage.write(doc)
          end

          # :nodoc:
          module Storage
            extend StorageModule
            def self.find_children_of_id(id)
              cache.values.select { |document| document.parent_ids.include?(id) }
            end
          end
          private_constant :Storage
        end
        private_constant :Index
      end
    end
  end
end
