require 'samvera/nesting_indexer/adapters/abstract_adapter'
require 'samvera/nesting_indexer/documents'

module Samvera
  module NestingIndexer
    module Adapters
      # @api public
      #
      # Defines the interface for interacting with the InMemory layer. It is a reference
      # implementation that is used throughout tests.
      module InMemoryAdapter
        extend AbstractAdapter
        # @api public
        # @param id [String]
        # @return Samvera::NestingIndexer::Document::PreservationDocument
        def self.find_preservation_document_by(id:)
          Preservation.find(id)
        end

        # @api public
        # @param id [String]
        # @return Samvera::NestingIndexer::Documents::IndexDocument
        def self.find_index_document_by(id:)
          Index.find(id)
        end

        # @api public
        # @yield Samvera::NestingIndexer::Document::PreservationDocument
        def self.each_preservation_document(&block)
          Preservation.find_each { |document| block.call(document) }
        end

        # @api public
        # @param document [Samvera::NestingIndexer::Documents::IndexDocument]
        # @yield Samvera::NestingIndexer::Documents::IndexDocument
        def self.each_child_document_of(document:, &block)
          Index.each_child_document_of(document: document, &block)
        end

        # @api public
        # This is not something that I envision using in the production environment;
        # It is hear to keep the Preservation system isolated and accessible only through interfaces.
        # @param attributes [Hash]
        # @return Samvera::NestingIndexer::Documents::PreservationDocument
        def self.write_document_attributes_to_preservation_layer(attributes)
          Preservation.write_document(attributes)
        end

        # @api public
        # @see README.md
        # @param id [String]
        # @param parent_ids [Array<String>]
        # @param ancestors [Array<String>]
        # @param pathnames [Array<String>]
        # @return Hash - the attributes written to the indexing layer
        def self.write_document_attributes_to_index_layer(id:, parent_ids:, ancestors:, pathnames:)
          Index.write_document(id: id, parent_ids: parent_ids, ancestors: ancestors, pathnames: pathnames)
        end

        # @api private
        def self.clear_cache!
          Preservation.clear_cache!
          Index.clear_cache!
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
            cache.each { |_key, document| yield(document) }
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

          def self.each_child_document_of(document:, &block)
            Storage.find_children_of_id(document.id).each(&block)
          end

          def self.write_document(attributes = {})
            Documents::IndexDocument.new(attributes).tap { |doc| Storage.write(doc) }
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
