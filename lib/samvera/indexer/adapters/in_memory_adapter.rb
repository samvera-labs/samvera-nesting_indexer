require 'samvera/indexer/adapters/abstract_adapter'
require 'samvera/indexer/documents'

module Samvera
  module Indexer
    module Adapters
      # @api public
      #
      # Defines the interface for interacting with the InMemory layer. It is a reference
      # implementation that is used throughout tests.
      module InMemoryAdapter
        extend AbstractAdapter
        # @api public
        # @param pid [String]
        # @return Samvera::Indexer::Document::PreservationDocument
        def self.find_preservation_document_by(pid)
          Preservation.find(pid)
        end

        # @api public
        # @param pid [String]
        # @return Samvera::Indexer::Documents::IndexDocument
        def self.find_index_document_by(pid)
          Index.find(pid)
        end

        # @api public
        # @yield Samvera::Indexer::Document::PreservationDocument
        def self.each_preservation_document
          Preservation.find_each { |document| yield(document) }
        end

        # @api public
        # @param document [Samvera::Indexer::Documents::IndexDocument]
        # @yield Samvera::Indexer::Documents::IndexDocument
        def self.each_child_document_of(document, &block)
          Index.each_child_document_of(document, &block)
        end

        # @api public
        # This is not something that I envision using in the production environment;
        # It is hear to keep the Preservation system isolated and accessible only through interfaces.
        # @return Samvera::Indexer::Documents::PreservationDocument
        def self.write_document_attributes_to_preservation_layer(attributes = {})
          Preservation.write_document(attributes)
        end

        # @api public
        # @return Hash - the attributes written to the indexing layer
        def self.write_document_attributes_to_index_layer(attributes = {})
          Index.write_document(attributes)
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
        #     extend Samvera::Indexer::StorageModule
        #   end
        module StorageModule
          def write(doc)
            cache[doc.pid] = doc
          end

          def find(pid)
            cache.fetch(pid.to_s)
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
        # In the case of SamveraND, there will need to be an adapter to get a Fedora
        # object coerced into a Samvera::Indexer::Preservation::Document
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

        # @api private
        #
        # An abstract representation of the underlying index service. In the case of
        # SamveraND this is an abstraction of Solr.
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
  end
end
