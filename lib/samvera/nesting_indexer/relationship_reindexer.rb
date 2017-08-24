require 'samvera/nesting_indexer/exceptions'
require 'forwardable'
require 'set'

module Samvera
  # Establishing namespace
  module NestingIndexer
    # Responsible for reindexing the PID and its descendants
    # @note There is cycle detection via the TIME_TO_LIVE counter
    # @api private
    class RelationshipReindexer
      # @api private
      #
      # A convenience method that coordinate the relationship reindexing of the given pid.
      #
      # @param options [Hash]
      # @option options [String] pid
      # @option options [Integer] maximum_nesting_depth Samvera::NestingIndexer::TIME_TO_LIVE to detect cycles in the graph
      # @option options [Samvera::NestingIndexer::Adapters::AbstractAdapter] adapter
      # @option options [#shift, #push] queue
      # @return Samvera::NestingIndexer::RelationshipReindexer
      def self.call(options = {})
        new(options).call
      end

      def initialize(options = {})
        @pid = options.fetch(:pid).to_s
        @maximum_nesting_depth = options.fetch(:maximum_nesting_depth).to_i
        @adapter = options.fetch(:adapter)
        @queue = options.fetch(:queue, [])
      end
      attr_reader :pid, :maximum_nesting_depth, :queue, :adapter

      # Perform a bread-first tree traversal of the initial document and its descendants.
      def call
        enqueue(initial_index_document, maximum_nesting_depth)
        processing_document = dequeue
        while processing_document
          process_a_document(processing_document)
          adapter.each_child_document_of(processing_document) { |child| enqueue(child, processing_document.maximum_nesting_depth - 1) }
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
        def initialize(document, maximum_nesting_depth)
          @maximum_nesting_depth = maximum_nesting_depth
          super(document)
        end
        attr_reader :maximum_nesting_depth
      end
      private_constant :ProcessingDocument
      def enqueue(document, maximum_nesting_depth)
        queue.push(ProcessingDocument.new(document, maximum_nesting_depth))
      end

      def process_a_document(index_document)
        raise Exceptions::CycleDetectionError, pid if index_document.maximum_nesting_depth <= 0
        preservation_document = adapter.find_preservation_document_by(index_document.pid)
        parent_pids_and_path_and_ancestors = parent_pids_and_path_and_ancestors_for(preservation_document)
        adapter.write_document_attributes_to_index_layer(parent_pids_and_path_and_ancestors)
      end

      def parent_pids_and_path_and_ancestors_for(preservation_document)
        ParentAndPathAndAncestorsBuilder.new(preservation_document, adapter).to_hash
      end

      # A small object that helps encapsulate the logic of building the hash of information regarding
      # the initialization of an Samvera::NestingIndexer::Documents::IndexDocument
      #
      # @see Samvera::NestingIndexer::Documents::IndexDocument for details on pathnames, ancestors, and parent_pids.
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
