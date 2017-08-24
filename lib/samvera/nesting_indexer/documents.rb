require 'dry-equalizer'

module Samvera
  module NestingIndexer
    module Documents
      # @api public
      #
      # A simplified document that reflects the necessary attributes for re-indexing
      # the children of Fedora objects.
      class PreservationDocument
        def initialize(keywords = {})
          @pid = keywords.fetch(:pid).to_s
          @parent_pids = Array(keywords.fetch(:parent_pids))
        end

        # @api public
        # @return String The Fedora object's PID
        attr_reader :pid

        # @api public
        #
        # All of the direct parents of the Fedora document associated with the given PID.
        #
        # This does not include grandparents, great-grandparents, etc.
        # @return Array<String>
        attr_reader :parent_pids
      end

      # @api public
      #
      # A rudimentary representation of what is needed to reindex Solr documents
      class IndexDocument
        # A quick and dirty means of doing comparative logic
        include Dry::Equalizer(:pid, :sorted_parent_pids, :sorted_pathnames, :sorted_ancestors)

        def initialize(keywords = {})
          @pid = keywords.fetch(:pid).to_s
          @parent_pids = Array(keywords.fetch(:parent_pids))
          @pathnames = Array(keywords.fetch(:pathnames))
          @ancestors = Array(keywords.fetch(:ancestors))
        end

        # @api public
        # @return String The Fedora object's PID
        attr_reader :pid

        # @api public
        #
        # All of the direct parents of the Fedora document associated with the given PID.
        #
        # This does not include grandparents, great-grandparents, etc.
        # @return Array<String>
        attr_reader :parent_pids

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
        #   [D/B], [C/B]
        #
        # @return Array<String>
        attr_reader :ancestors

        def sorted_parent_pids
          parent_pids.sort
        end

        def sorted_pathnames
          pathnames.sort
        end

        def sorted_ancestors
          ancestors.sort
        end
      end
    end
  end
end
