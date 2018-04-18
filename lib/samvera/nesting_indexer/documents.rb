require 'dry-equalizer'

module Samvera
  module NestingIndexer
    # @api public
    module Documents
      ANCESTOR_AND_PATHNAME_DELIMITER = '/'.freeze

      # @api private
      #
      # A simplified document that reflects the necessary attributes for re-indexing
      # the children of Fedora objects.
      class PreservationDocument
        def initialize(keywords = {})
          @id = keywords.fetch(:id).to_s
          @parent_ids = Array(keywords.fetch(:parent_ids))
        end

        # @api private
        # @return String The Fedora object's PID
        attr_reader :id

        # @api private
        #
        # All of the direct parents of the Fedora document associated with the given PID.
        #
        # This does not include grandparents, great-grandparents, etc.
        # @return Array<String>
        attr_reader :parent_ids
      end

      # @api public
      #
      # A rudimentary representation of what is needed to reindex Solr documents
      class IndexDocument
        # A quick and dirty means of doing comparative logic
        include Dry::Equalizer(:id, :sorted_parent_ids, :sorted_pathnames, :sorted_ancestors)

        def initialize(keywords = {})
          @id = keywords.fetch(:id).to_s
          @parent_ids = Array(keywords.fetch(:parent_ids))
          @pathnames = Array(keywords.fetch(:pathnames))
          @ancestors = Array(keywords.fetch(:ancestors))
        end

        # @api public
        # @since v1.0.0
        # @return [Hash<Symbol,>] the Ruby hash representation of this index document.
        def to_hash
          {
            id: id,
            parent_ids: parent_ids,
            pathnames: pathnames,
            ancestors: ancestors,
            deepest_nested_depth: deepest_nested_depth
          }
        end

        # @api public
        # @return String The Fedora object's PID
        attr_reader :id

        # @api public
        #
        # All of the direct parents of the Fedora document associated with the given PID.
        #
        # This does not include grandparents, great-grandparents, etc.
        # @return Array<String>
        attr_reader :parent_ids

        # @api public
        #
        # All nodes in the graph are addressable by one or more pathnames.
        #
        # If I have A, with parent B, and B has parents C and D, we have the
        # following pathnames:
        #   [D/B/A, C/B/A]
        #
        # In the graph representation, we can get to A by going from D to B to A, or by going from C to B to A.
        # @return Array<String>
        attr_reader :pathnames

        # @api public
        #
        # All of the :pathnames of each of the documents ancestors. If I have A, with parent B, and B has
        # parents C and D then we have the following ancestors:
        #   [D], [C], [D/B], [C/B]
        #
        # @return Array<String>
        attr_reader :ancestors

        # @api public
        # @since v1.0.0
        #
        # The largest nesting depth of this document. If I have A ={ B ={ C and D ={ C, then
        # deepest_nested_depth is 3.
        #
        # @return Integer
        def deepest_nested_depth
          pathnames.map do |pathname|
            pathname.split(ANCESTOR_AND_PATHNAME_DELIMITER).count
          end.max
        end

        # @api private
        def sorted_parent_ids
          parent_ids.sort
        end

        # @api private
        def sorted_pathnames
          pathnames.sort
        end

        # @api private
        def sorted_ancestors
          ancestors.sort
        end
      end
    end
  end
end
