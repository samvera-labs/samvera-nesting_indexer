require "curate/indexer/version"
require "curate/indexer/caching_module"
require "curate/indexer/reindexer"
require "curate/indexer/persistence"
require "curate/indexer/indexing_document"

require 'set'

module Curate
  # Responsible for the indexing strategy of related objects
  module Indexer
    # I don't want the inner workings exposed to other systems
    private_constant :CachingModule
    private_constant :Queue
    private_constant :Reindexer
    private_constant :IndexingDocument

    def self.reindex(pid:, max_level: 20)
      Reindexer.new(requested_pid: pid, max_level: max_level).reindex
    end

    # Represents the interaction with the index
    module Index
      def self.new_rebuilder(requested_for:)
        Rebuilder.new(requested_for: requested_for)
      end
      # Responsible for co-ordinating the rebuild of the index
      class Rebuilder
        def initialize(requested_for:)
          self.requested_for = requested_for
          self.cache = {}
        end

        def associate(document:, member_of_document:)
          document_writer = find_or_build_writer_for(document: document)
          member_of_writer = find_or_build_writer_for(document: member_of_document)

          # Ensure the relationships are copied onto the document
          copy_relationships(target: document_writer, source: document)
          copy_relationships(target: member_of_writer, source: member_of_document)

          # Business logic of writing relationships
          document_writer.add_member_of(member_of_writer.pid)
          document_writer.add_transitive_member_of(member_of_writer.pid, *member_of_writer.transitive_member_of)
          member_of_writer.add_collection_members(document_writer.pid)
          member_of_writer.add_transitive_collection_members(document_writer.pid, *document_writer.transitive_collection_members)
        end

        def copy_relationships(target:, source:)
          target.add_transitive_member_of(source.transitive_member_of)
          target.add_member_of(source.member_of)
          target.add_collection_members(source.collection_members)
          target.add_transitive_collection_members(source.transitive_collection_members)
        end

        def rebuild_and_return_requested_for
          returning_value = nil
          cache.each_value do |writer_document|
            writer_document.write! # Persist to the index
            returning_value = writer_document if requested_for.pid == writer_document.pid
          end
          returning_value
        end

        def visited_pids
          cache.keys
        end

        attr_reader :requested_for

        private

        attr_writer :requested_for
        attr_accessor :cache

        def find_or_build_writer_for(document:)
          cache[document.pid] ||= Document.new(pid: document.pid)
        end
      end

      # Responsible for representing an index document
      class Document < IndexingDocument
        def write!
          Index::Query.cache[pid] = self
        end
      end

      # Contains the Query interactions with the Index
      module Query
        extend CachingModule
        def self.find(pid)
          cache.fetch(pid)
        rescue KeyError
          cache[pid] = Document.new(pid: pid)
        end
      end
    end

    # Responsible for coordinating all of the building process of the new index
    # data.
    module Processing
      extend CachingModule
      def self.find_or_create_processing_document_for(pid:, level:, **keywords)
        cache.fetch(pid).fetch(level)
      rescue KeyError
        cache[pid] ||= {}
        cache[pid][level] = Builder.new(pid: pid, level: level, **keywords).build
      end

      # Responsible for building a processing document by "smashing" together a persisted document
      # and its index representation.
      class Builder
        def initialize(pid:, level:, persistence_finder: default_persistence_finder, index_finder: default_index_finder)
          self.pid = pid
          self.level = level
          self.persistence_finder = persistence_finder
          self.index_finder = index_finder
        end

        def build
          persisted_document = persistence_finder.call(pid: pid)
          index_document = index_finder.call(pid: pid)
          build_from(persisted_document: persisted_document, index_document: index_document)
        end

        attr_reader :pid, :level, :persistence_finder, :index_finder

        private

        attr_writer :pid, :level, :persistence_finder, :index_finder

        def build_from(persisted_document:, index_document:)
          Document.new(pid: pid, level: level) do
            add_transitive_member_of(index_document.transitive_member_of)
            add_member_of(persisted_document.member_of)
            add_transitive_collection_members(index_document.transitive_collection_members)
            add_collection_members(index_document.collection_members)
          end
        end

        def default_persistence_finder
          ->(pid:) { Persistence.find(pid) }
        end

        def default_index_finder
          ->(pid:) { Index::Query.find(pid) }
        end
      end
      private_constant :Builder

      # Represents a document under processing
      # @see Builder
      class Document < IndexingDocument
        attr_reader :pid, :level
        def initialize(pid:, level:, &block)
          self.level = level
          super(pid: pid, &block)
        end

        private

        attr_writer :pid, :level
      end
      private_constant :Document
    end
  end
end
