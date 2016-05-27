require "curate/indexer/version"

require 'set'

module Curate
  # Responsible for the indexing strategy of related objects
  module Indexer
    # Namespacing for common errors
    class RuntimeError < RuntimeError
    end
    # An exception thrown when a possible cycle is detected in the graph.
    class ReindexingReachedMaxLevelError < RuntimeError
      attr_accessor :requested_pid, :visited_pids, :max_level
      def initialize(requested_pid:, visited_pids:, max_level:)
        self.requested_pid = requested_pid
        self.visited_pids = visited_pids
        self.max_level = max_level
        super("ERROR: Reindexing reached level #{max_level} on PID:#{requested_pid}. Possible graph cycle detected.")
      end
    end

    # An assistive class in the breadth first search.
    class Queue
      def initialize
        @queue = []
      end

      def enqueue(object)
        @queue << object
      end

      def dequeue
        @queue.shift
      end
    end
    private_constant :Queue

    # There are several layers of caching involved, this provides some of the common behavior.
    module Cache
      def find(key, &block)
        cache.fetch(key, &block)
      end

      def cache
        @cache ||= {}
      end

      def add_to_cache(key, value)
        cache[key] ||= value
      end

      def clear_cache!
        @cache = {}
      end
    end
    private_constant :Cache

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
          member_writer = find_or_build_writer_for(document: member_of_document)
          [
            :is_transitive_member_of, :member_of, :has_collection_members, :has_transitive_collection_members
          ].each do |method_name|
            document_writer.public_send("add_#{method_name}", *document.public_send(method_name))
            member_writer.public_send("add_#{method_name}", *member_of_document.public_send(method_name))
          end
          document_writer.add_member_of(member_writer.pid)
          document_writer.add_is_transitive_member_of(member_writer.pid, *member_writer.is_transitive_member_of)
          member_writer.add_has_collection_members(document_writer.pid)
          member_writer.add_has_transitive_collection_members(document_writer.pid, *document_writer.has_transitive_collection_members)
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
      class Document
        attr_reader :pid
        def initialize(pid:)
          self.pid = pid
          instance_exec { yield(self) } if block_given?
          # Ensuring that transitive relations always contain direct members
          add_is_transitive_member_of(member_of)
          add_has_transitive_collection_members(has_collection_members)
        end

        [
          :is_transitive_member_of,
          :member_of,
          :has_collection_members,
          :has_transitive_collection_members
        ].each do |method_name|
          define_method(method_name) do
            (instance_variable_get("@#{method_name}") || []).to_a
          end

          define_method("#{method_name}=") do |values|
            send("add_#{method_name}", values)
          end

          define_method("add_#{method_name}") do |*pids|
            if instance_variable_get("@#{method_name}")
              instance_variable_set("@#{method_name}", (instance_variable_get("@#{method_name}") + Array(pids).flatten))
            else
              instance_variable_set("@#{method_name}", Set.new(Array(pids).flatten))
            end
          end
        end

        def write!
          Index::Query.cache[pid] = self
        end

        private

        attr_writer :pid
      end

      # Contains the Query interactions with the Index
      module Query
        extend Cache
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
      extend Cache
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
          Document.new(pid: pid, level: level) do |query_document|
            query_document.is_transitive_member_of = index_document.is_transitive_member_of
            query_document.member_of = persisted_document.member_of
            query_document.has_transitive_collection_members = index_document.has_transitive_collection_members
            query_document.has_collection_members = index_document.has_collection_members
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
      class Document
        attr_reader :pid, :level
        def initialize(pid:, level:)
          self.pid = pid
          self.level = level
          instance_exec { yield(self) } if block_given?
          # Ensuring that transitive relations always contain direct members
          self.is_transitive_member_of = is_transitive_member_of + member_of
          self.has_transitive_collection_members = has_transitive_collection_members + has_collection_members
        end

        [
          :is_transitive_member_of,
          :member_of,
          :has_collection_members,
          :has_transitive_collection_members
        ].each do |method_name|
          define_method(method_name) do
            (instance_variable_get("@#{method_name}") || []).to_a
          end

          define_method("#{method_name}=") do |values|
            instance_variable_set("@#{method_name}", Set.new(Array(values)))
          end
        end

        private

        attr_writer :pid, :level
      end
      private_constant :Document
    end

    # Responsible for being a layer between Fedora and the heavy lifting of the
    # reindexing processor. It has aspects that will need to change.
    module Persistence
      extend Cache

      # This is a disposable intermediary between Fedora and the processing system for reindexing.
      class Document
        attr_reader :pid, :member_of
        def initialize(pid:, member_of: [])
          # A concession that when I make something it should be persisted.
          Persistence.add_to_cache(pid, self)
          self.pid = pid
          self.member_of = member_of
        end

        def add_member_of(*pids)
          @member_of += Array(pids).compact
        end

        private

        attr_writer :pid
        def member_of=(input)
          # I'd prefer Array.wrap, but I'm assuming we won't have a DateTime object
          @member_of = Set.new(Array(input).compact)
        end
      end
      private_constant :Document

      class Collection < Document
      end

      class Work < Document
      end
    end

    def self.reindex(pid:, max_level: 20)
      Reindexer.new(requested_pid: pid, max_level: max_level).reindex
    end

    # Coordinates the reindexing of the entire direct relationship graph
    class Reindexer
      def initialize(requested_pid:, max_level:)
        self.requested_pid = requested_pid
        self.max_level = max_level
        @document_to_reindex = Processing.find_or_create_processing_document_for(pid: requested_pid, level: 0)
        @rebuilder = Index.new_rebuilder(requested_for: document_to_reindex)
        @queue = Queue.new
      end
      attr_reader :requested_pid, :max_level, :rebuilder, :document_to_reindex, :queue

      def reindex
        document = document_to_reindex
        while document
          document.member_of.each do |member_of_pid|
            reindex_relation(document: document, member_of_pid: member_of_pid)
          end
          document = queue.dequeue
        end
        rebuilder.rebuild_and_return_requested_for
      end

      private

      attr_writer :requested_pid, :max_level

      def reindex_relation(document:, member_of_pid:)
        next_level = document.level + 1
        guard_max_level_achieved!(next_level: next_level)
        member_of_document = Processing.find_or_create_processing_document_for(pid: member_of_pid, level: next_level)
        rebuilder.associate(document: document, member_of_document: member_of_document)
        queue.enqueue(member_of_document)
      end

      def guard_max_level_achieved!(next_level:)
        return true if next_level < max_level
        raise(
          ReindexingReachedMaxLevelError,
          requested_pid: requested_pid,
          visited_pids: rebuilder.visited_pids,
          max_level: max_level
        )
      end
    end
    private_constant :Reindexer
  end
end
