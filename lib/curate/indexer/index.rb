require 'dry-initializer'
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
        extend Dry::Initializer::Mixin
        option :pid, type: Types::Coercible::String
        option :parents, type: Types::Coercible::Array
        option :pathnames, type: Types::Coercible::Array
        option :ancestors, type: Types::Coercible::Array

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
