require "curate/indexer/version"
require 'curate/indexer/relationship_reindexer'
require 'curate/indexer/repository_reindexer'

module Curate
  # Responsible for the indexing strategy of related objects
  module Indexer
    # This assumes a rather deep graph
    DEFAULT_TIME_TO_LIVE = 15
    # @api public
    # Responsible for reindexing the descendants of a pid. In a perfect world
    # we could reindex the pid as well; But that is for another test.
    def self.reindex_relationships(pid, time_to_live = DEFAULT_TIME_TO_LIVE)
      RelationshipReindexer.call(pid: pid, time_to_live: time_to_live)
    end

    class << self
      alias reindex reindex_relationships
    end

    # @api public
    # Responsible for reindexing the entire preservation layer.
    def self.reindex_all!(time_to_live = DEFAULT_TIME_TO_LIVE)
      RepositoryReindexer.call(time_to_live: time_to_live, pid_reindexer: method(:reindex_relationships))
    end
  end
end
