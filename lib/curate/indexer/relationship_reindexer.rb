require 'curate/indexer/exceptions'
require 'curate/indexer/index'
require 'curate/indexer/preservation'
require 'forwardable'
require 'set'

module Curate
  module Indexer
    # Responsible for reindexing the PID and its descendants
    # @note There is cycle detection via the TIME_TO_LIVE counter
    # @api private
    class RelationshipReindexer
      def initialize(options = {})
        @pid = options.fetch(:pid).to_s
        @time_to_live = options.fetch(:time_to_live).to_i
        @queue = options.fetch(:queue, [])
      end
      attr_reader :pid, :time_to_live, :queue

      def call
        enqueue(pid, time_to_live)
        index_document = dequeue
        while index_document
          process_a_document(index_document)
          with_each_indexed_child_of(index_document.pid) { |child| enqueue(child.pid, index_document.time_to_live - 1) }
          index_document = dequeue
        end
        self
      end

      private

      def with_each_indexed_child_of(pid)
        Index::Storage.find_children_of_pid(pid).each { |child| yield(child) }
      end

      attr_writer :document

      extend Forwardable
      def_delegator :queue, :shift, :dequeue

      ProcessingDocument = Struct.new(:pid, :time_to_live)
      private_constant :ProcessingDocument
      def enqueue(pid, time_to_live)
        queue.push(ProcessingDocument.new(pid, time_to_live))
      end

      def process_a_document(index_document)
        raise Exceptions::CycleDetectionError, pid if index_document.time_to_live <= 0
        preservation_document = Preservation::Storage.find(index_document.pid)
        Index::Document.new(parent_pids_and_path_and_ancestors_for(preservation_document)).write
      end

      def parent_pids_and_path_and_ancestors_for(preservation_document)
        ParentAndPathAndAncestorsBuilder.new(preservation_document).to_hash
      end

      # A small object that helps encapsulate the logic of building the hash of information regarding
      # the initialization of an Index::Document
      class ParentAndPathAndAncestorsBuilder
        def initialize(preservation_document)
          @preservation_document = preservation_document
          @parent_pids = Set.new
          @pathnames = Set.new
          @ancestors = Set.new
          compile!
        end

        def to_hash
          { pid: @preservation_document.pid, parent_pids: @parent_pids.to_a, pathnames: @pathnames.to_a, ancestors: @ancestors.to_a }
        end

        private

        def compile!
          @preservation_document.parent_pids.each do |parent_pid|
            parent_index_document = Index::Storage.find(parent_pid)
            compile_one!(parent_index_document)
          end
        end

        def compile_one!(parent_index_document)
          @parent_pids << parent_index_document.pid
          parent_index_document.pathnames.each do |pathname|
            @pathnames << File.join(pathname, @preservation_document.pid)
            slugs = pathname.split("/")
            slugs.each_index { |i| @ancestors << slugs[0..i].join('/') }
          end
          @ancestors += parent_index_document.ancestors
        end
      end
      private_constant :ParentAndPathAndAncestorsBuilder
    end
  end
end
