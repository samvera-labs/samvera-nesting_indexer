require 'dry-equalizer'

module Curate
  module Indexer
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
        attr_reader :pid, :parent_pids
      end

      # @api private
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
        attr_reader :pid, :parent_pids, :pathnames, :ancestors

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
