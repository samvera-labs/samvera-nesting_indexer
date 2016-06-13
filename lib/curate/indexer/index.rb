require 'dry-equalizer'
require 'curate/indexer/storage_module'

module Curate
  module Indexer
    # @api private
    #
    # An abstract representation of the underlying index service. In the case of
    # CurateND this is an abstraction of Solr.
    module Index
      def self.find(pid)
        Storage.find(pid)
      end

      # @api private
      #
      # A rudimentary representation of what is needed to reindex Solr documents
      class Document
        # A quick and dirty means of doing comparative logic
        include Dry::Equalizer(:pid, :sorted_parent_pids, :sorted_pathnames, :sorted_ancestors)

        def initialize(keywords = {})
          @pid = keywords.fetch(:pid).to_s
          @parent_pids = Array(keywords.fetch(:parent_pids))
          @pathnames = Array(keywords.fetch(:pathnames))
          @ancestors = Array(keywords.fetch(:ancestors))
        end
        attr_reader :pid, :parent_pids, :pathnames, :ancestors

        def write
          Storage.write(self)
        end

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

      # :nodoc:
      module Storage
        extend StorageModule
        def self.find_children_of_pid(pid)
          cache.values.select { |document| document.parent_pids.include?(pid) }
        end
      end
    end
  end
end
