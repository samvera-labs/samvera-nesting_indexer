require "curate/indexer/version"
require 'curate/indexer/descendants_reindexer'

module Curate
  # Responsible for the indexing strategy of related objects
  module Indexer
    # This assumes a rather deep graph
    DEFAULT_TIME_TO_LIVE = 15
    def self.reindex_descendants(pid, time_to_live = DEFAULT_TIME_TO_LIVE)
      DescendantReindexer.new(pid: pid, time_to_live: time_to_live).call
    end
  end
end
