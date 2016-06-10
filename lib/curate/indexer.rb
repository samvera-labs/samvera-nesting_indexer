require "curate/indexer/version"
require 'curate/indexer/relationship_reindexer'

module Curate
  # Responsible for the indexing strategy of related objects
  module Indexer
    # This assumes a rather deep graph
    DEFAULT_TIME_TO_LIVE = 15
    # @api public
    # Responsible for reindexing the descendants of a pid. In a perfect world
    # we could reindex the pid as well; But that is for another test.
    def self.reindex_relationships(pid, time_to_live = DEFAULT_TIME_TO_LIVE)
      RelationshipReindexer.new(pid: pid, time_to_live: time_to_live).call
    end

    # @api public
    # Responsible for reindexing the entire preservation layer.
    def self.reindex_all!
      Preservation::Storage.each { |document| reindex_one_of_many!(document) }
    end

    # Given that we are attempting to reindex the parents before we reindex, we can't rely on
    # the reindex time_to_live but instead must have a separate time to live.
    #
    # The reindexing process assumes that an object's parents have been indexed; Thus we need to
    # walk up the parent graph to reindex the parents before we start on the child.
    def self.reindex_one_of_many!(document, processed_pids = [], time_to_live = DEFAULT_TIME_TO_LIVE)
      return true if processed_pids.include?(document.pid)
      raise Exceptions::CycleDetectionError, document.pid if time_to_live <= 0
      document.parent_pids.each do |parent_pid|
        parent_document = Preservation::Storage.find(parent_pid)
        reindex_one_of_many!(parent_document, processed_pids, time_to_live - 1)
      end
      reindex_relationships(document.pid)
    end
    private_class_method :reindex_one_of_many!

    class << self
      alias reindex reindex_relationships
    end
  end
end
