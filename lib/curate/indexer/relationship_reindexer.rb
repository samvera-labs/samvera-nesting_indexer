require 'curate/indexer/exceptions'
require 'forwardable'
require 'set'

module Curate
  # Establishing namespace
  module Indexer
    # Responsible for reindexing the PID and its descendants
    # @note There is cycle detection via the TIME_TO_LIVE counter
    # @api private
    class RelationshipReindexer
      def self.call(options = {})
        new(options).call
      end

      def initialize(options = {})
        @pid = options.fetch(:pid).to_s
        @time_to_live = options.fetch(:time_to_live).to_i
        @adapter = options.fetch(:adapter)
        @queue = options.fetch(:queue, [])
      end
      attr_reader :pid, :time_to_live, :queue, :adapter

      def call
        enqueue(initial_index_document, time_to_live)
        processing_document = dequeue
        while processing_document
          process_a_document(processing_document)
          adapter.each_child_document_of(processing_document) { |child| enqueue(child, processing_document.time_to_live - 1) }
          processing_document = dequeue
        end
        self
      end

      private

      attr_writer :document

      def initial_index_document
        adapter.find_index_document_by(pid)
      end

      extend Forwardable
      def_delegator :queue, :shift, :dequeue

      require 'delegate'
      # A small object to help track time to live concerns
      class ProcessingDocument < SimpleDelegator
        def initialize(document, time_to_live)
          @time_to_live = time_to_live
          super(document)
        end
        attr_reader :time_to_live
      end
      private_constant :ProcessingDocument
      def enqueue(document, time_to_live)
        queue.push(ProcessingDocument.new(document, time_to_live))
      end

      def process_a_document(index_document)
        raise Exceptions::CycleDetectionError, pid if index_document.time_to_live <= 0
        preservation_document = adapter.find_preservation_document_by(index_document.pid)
        adapter.write_document_attributes_to_index_layer(parent_pids_and_path_and_ancestors_for(preservation_document))
      end

      def parent_pids_and_path_and_ancestors_for(preservation_document)
        ParentAndPathAndAncestorsBuilder.new(preservation_document, adapter).to_hash
      end

      # A small object that helps encapsulate the logic of building the hash of information regarding
      # the initialization of an Index::Document
      class ParentAndPathAndAncestorsBuilder
        def initialize(preservation_document, adapter)
          @preservation_document = preservation_document
          @parent_pids = Set.new
          @pathnames = Set.new
          @ancestors = Set.new
          @adapter = adapter
          compile!
        end

        def to_hash
          { pid: @preservation_document.pid, parent_pids: @parent_pids.to_a, pathnames: @pathnames.to_a, ancestors: @ancestors.to_a }
        end

        private

        attr_reader :adapter

        def compile!
          @preservation_document.parent_pids.each do |parent_pid|
            parent_index_document = adapter.find_index_document_by(parent_pid)
            compile_one!(parent_index_document)
          end
          # Ensuring that an "orphan" has a path to get to it
          @pathnames << @preservation_document.pid if @parent_pids.empty?
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
    private_constant :RelationshipReindexer
  end
end
