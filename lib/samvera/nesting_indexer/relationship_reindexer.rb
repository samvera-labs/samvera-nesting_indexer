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
      # A convenience method that coordinate the relationship reindexing of the given id.
      #
      # @see #initialize
      # @return Samvera::NestingIndexer::RelationshipReindexer
      def self.call(**kwargs)
        new(**kwargs).call
      end

      # @param id [String]
      # @param maximum_nesting_depth [Integer] Samvera::NestingIndexer::TIME_TO_LIVE to detect cycles in the graph
      # @param configuration [#adapter, #logger] The :adapter conforms to the Samvera::NestingIndexer::Adapters::AbstractAdapter interface
      #                                          and the :logger conforms to Logger
      # @param queue [#shift, #push] queue
      def initialize(id:, maximum_nesting_depth:, configuration:, queue: [])
        @id = id.to_s
        @maximum_nesting_depth = maximum_nesting_depth.to_i
        @configuration = configuration
        @queue = queue
      end
      attr_reader :id, :maximum_nesting_depth

      # Perform a bread-first tree traversal of the initial document and its descendants.
      # rubocop:disable Metrics/AbcSize
      def call
        wrap_logging("nested indexing of ID=#{initial_index_document.id.inspect}") do
          enqueue(initial_index_document, maximum_nesting_depth)
          processing_document = dequeue
          while processing_document
            process_a_document(processing_document)
            adapter.each_child_document_of(document: processing_document) { |child| enqueue(child, processing_document.maximum_nesting_depth - 1) }
            processing_document = dequeue
          end
        end
        self
      end
      # rubocop:enbable Metrics/AbcSize

      private

      attr_reader :queue, :configuration

      def initial_index_document
        adapter.find_index_document_by(id: id)
      end

      extend Forwardable
      def_delegator :queue, :shift, :dequeue
      def_delegator :configuration, :adapter
      def_delegator :configuration, :logger

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
        raise Exceptions::CycleDetectionError, id if index_document.maximum_nesting_depth <= 0
        wrap_logging("indexing ID=#{index_document.id.inspect}") do
          preservation_document = adapter.find_preservation_document_by(id: index_document.id)
          parent_ids_and_path_and_ancestors = parent_ids_and_path_and_ancestors_for(preservation_document)
          adapter.write_document_attributes_to_index_layer(**parent_ids_and_path_and_ancestors)
        end
      end

      def parent_ids_and_path_and_ancestors_for(preservation_document)
        ParentAndPathAndAncestorsBuilder.new(preservation_document, adapter).to_hash
      end

      def wrap_logging(message_suffix)
        logger.debug("Starting #{message_suffix}")
        yield
        logger.debug("Ending #{message_suffix}")
      end

      # A small object that helps encapsulate the logic of building the hash of information regarding
      # the initialization of an Samvera::NestingIndexer::Documents::IndexDocument
      #
      # @see Samvera::NestingIndexer::Documents::IndexDocument for details on pathnames, ancestors, and parent_ids.
      class ParentAndPathAndAncestorsBuilder
        def initialize(preservation_document, adapter)
          @preservation_document = preservation_document
          @parent_ids = Set.new
          @pathnames = Set.new
          @ancestors = Set.new
          @adapter = adapter
          compile!
        end

        def to_hash
          { id: @preservation_document.id, parent_ids: @parent_ids.to_a, pathnames: @pathnames.to_a, ancestors: @ancestors.to_a }
        end

        private

        attr_reader :adapter

        def compile!
          @preservation_document.parent_ids.each do |parent_id|
            parent_index_document = adapter.find_index_document_by(id: parent_id)
            compile_one!(parent_index_document)
          end
          # Ensuring that an "orphan" has a path to get to it
          @pathnames << @preservation_document.id if @parent_ids.empty?
        end

        def compile_one!(parent_index_document)
          @parent_ids << parent_index_document.id
          parent_index_document.pathnames.each do |pathname|
            @pathnames << File.join(pathname, @preservation_document.id)
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
