require 'set'
module Curate
  # Responsible for the indexing strategy of related objects
  module Indexer
    # Responsible for representing an index document
    class IndexingDocument
      attr_reader :pid
      def initialize(keywords = {}, &block)
        self.pid = keywords.fetch(:pid)
        initialize_relationship_sets!
        instance_exec(self, &block) if block_given?
        # Ensuring that transitive relations always contain direct members
        add_transitive_member_of(member_of)
        add_transitive_collection_members(collection_members)
      end

      def transitive_member_of
        @transitive_member_of.to_a
      end

      def member_of
        @member_of.to_a
      end

      def collection_members
        @collection_members.to_a
      end

      def transitive_collection_members
        @transitive_collection_members.to_a
      end

      def add_transitive_member_of(*pids)
        @transitive_member_of += pids.flatten.compact
      end

      def add_member_of(*pids)
        @member_of += pids.flatten.compact
      end

      def add_collection_members(*pids)
        @collection_members += pids.flatten.compact
      end

      def add_transitive_collection_members(*pids)
        @transitive_collection_members += pids.flatten.compact
      end

      private

      attr_writer :pid

      def initialize_relationship_sets!
        @transitive_member_of = Set.new
        @member_of = Set.new
        @transitive_collection_members = Set.new
        @collection_members = Set.new
      end
    end
  end
end
