require 'dry-equalizer'
require 'curate/indexer/storage_module'

module Curate
  module Indexer
    # An abstract representation of the underlying index service. In the case of
    # CurateND this is an abstraction of Solr.
    module Index
      # A rudimentary representation of what is needed to reindex Solr documents
      class Document
        # A quick and dirty means of doing comparative logic
        include Dry::Equalizer(:pid, :sorted_parents, :sorted_pathnames, :sorted_ancestors)

        def initialize(keywords = {})
          @pid = keywords.fetch(:pid).to_s
          @parents = Array(keywords.fetch(:parents))
          @pathnames = Array(keywords.fetch(:pathnames))
          @ancestors = Array(keywords.fetch(:ancestors))
        end
        attr_reader :pid, :parents, :pathnames, :ancestors

        def write
          Storage.write(self)
        end

        def sorted_parents
          parents.sort
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
          cache.values.select { |document| document.parents.include?(pid) }
        end
      end
    end
  end
end
