require "curate/indexer/version"
require "curate/indexer/caching_module"
require "curate/indexer/reindexer"
require "curate/indexer/persistence"
require "curate/indexer/indexing_document"
require "dry/equalizer"

require 'set'

module Curate
  # Responsible for the indexing strategy of related objects
  module Indexer
    # I don't want the inner workings exposed to other systems
    private_constant :CachingModule
    private_constant :Queue
    private_constant :Reindexer
    private_constant :IndexingDocument

    def self.reindex(keywords = {})
      max_level = keywords.fetch(:max_level, 20)
      Reindexer.new(requested_pid: keywords.fetch(:pid), max_level: max_level).reindex
    end

    # Represents the interaction with the index
    module Index
      def self.new_rebuilder(keywords = {})
        Rebuilder.new(keywords)
      end
      # Responsible for co-ordinating the rebuild of the index
      class Rebuilder
        def initialize(keywords = {})
          self.requested_for = keywords.fetch(:requested_for)
          self.cache = {}
        end

        def associate(keywords = {})
          document = keywords.fetch(:document)
          member_of_document = keywords.fetch(:member_of_document)
          document_writer = find_or_build_writer_for(document: document)
          member_of_writer = find_or_build_writer_for(document: member_of_document)

          # Ensure the relationships are copied onto the document
          copy_relationships(target: document_writer, source: document)
          copy_relationships(target: member_of_writer, source: member_of_document)

          associate_relationships_for_writers(document_writer, member_of_writer)
        end

        private

        def associate_relationships_for_writers(document_writer, member_of_writer)
          # Business logic of writing relationships
          document_writer.add_member_of(member_of_writer.pid)
          document_writer.add_transitive_member_of(member_of_writer.pid, *member_of_writer.transitive_member_of)
          member_of_writer.add_collection_members(document_writer.pid)
          member_of_writer.add_transitive_collection_members(document_writer.pid, *document_writer.transitive_collection_members)
        end

        def copy_relationships(keywords = {})
          target = keywords.fetch(:target)
          source = keywords.fetch(:source)
          target.add_transitive_member_of(source.transitive_member_of)
          target.add_member_of(source.member_of)
          target.add_collection_members(source.collection_members)
          target.add_transitive_collection_members(source.transitive_collection_members)
        end

        public

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

        def find_or_build_writer_for(keywords = {})
          document = keywords.fetch(:document)
          cache[document.pid] ||= Document.new(pid: document.pid)
        end
      end

      # Responsible for representing an index document
      class Document < IndexingDocument
        include Dry::Equalizer(:pid, :member_of, :transitive_member_of, :collection_members, :transitive_collection_members)
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
      def self.find_or_create_processing_document_for(keywords = {})
        pid = keywords.fetch(:pid)
        level = keywords.fetch(:level)
        begin
          cache.fetch(pid).fetch(level)
        rescue KeyError
          cache[pid] ||= {}
          cache[pid][level] = Builder.new(keywords).build
        end
      end

      # Responsible for building a processing document by "smashing" together a persisted document
      # and its index representation.
      class Builder
        def initialize(keywords = {})
          self.pid = keywords.fetch(:pid)
          self.level = keywords.fetch(:level)
          self.persistence_finder = keywords.fetch(:persistence_finder) { default_persistence_finder }
          self.index_finder = keywords.fetch(:index_finder) { default_index_finder }
        end

        def build
          persisted_document = persistence_finder.call(pid)
          index_document = index_finder.call(pid)
          build_from(persisted_document: persisted_document, index_document: index_document)
        end

        attr_reader :pid, :level, :persistence_finder, :index_finder

        private

        attr_writer :pid, :level, :persistence_finder, :index_finder

        def build_from(keywords = {})
          persisted_document = keywords.fetch(:persisted_document)
          index_document = keywords.fetch(:index_document)
          Document.new(pid: pid, level: level) do
            add_transitive_member_of(index_document.transitive_member_of)
            add_member_of(persisted_document.member_of)
            add_transitive_collection_members(index_document.transitive_collection_members)
            add_collection_members(index_document.collection_members)
          end
        end

        def default_persistence_finder
          ->(pid) { Persistence.find(pid) }
        end

        def default_index_finder
          ->(pid) { Index::Query.find(pid) }
        end
      end
      private_constant :Builder

      # Represents a document under processing
      # @see Builder
      class Document < IndexingDocument
        attr_reader :pid, :level
        def initialize(keywords = {}, &block)
          self.level = keywords.fetch(:level)
          super(pid: keywords.fetch(:pid), &block)
        end

        private

        attr_writer :pid, :level
      end
      private_constant :Document
    end
  end
end
