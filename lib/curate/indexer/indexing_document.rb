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
        add_transitive_members(members)
      end

      [:transitive_member_of, :member_of, :members, :transitive_members].each do |relationship_name|
        class_eval <<-EOV, __FILE__, __LINE__ + 1
          def #{relationship_name}
            @#{relationship_name}.map(&:last)
          end

          def add_#{relationship_name}(*pids)
            @#{relationship_name} += pids.flatten.compact.map {|p| [pid, p].flatten }
          end
        EOV
      end

      private

      attr_writer :pid

      def initialize_relationship_sets!
        [:transitive_member_of, :member_of, :members, :transitive_members].each do |relationship_name|
          instance_variable_set("@#{relationship_name}", Set.new)
        end
      end
    end
  end
end
