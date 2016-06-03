require 'set'
require 'curate/indexer/caching_module'
require 'curate/indexer/indexing_document'

module Curate
  module Indexer
    # Responsible for being a layer between Fedora and the heavy lifting of the
    # reindexing processor. It has aspects that will need to change.
    module Persistence
      extend CachingModule

      def self.find_or_build(pid)
        find(pid) do
          cache[pid] = Document.new(pid: pid)
        end
      end

      # This is a disposable intermediary between Fedora and the processing system for reindexing.
      # I believe it is a good idea to keep separation from the persistence layer and the processing.
      #
      # Unlike the IndexingDocument, the Persistence Document should only have the direct relationship
      # information.
      # @see Curate::Indexer::IndexingDocument
      class Document < IndexingDocument
        attr_reader :pid
        def initialize(keywords = {})
          super(pid: keywords.fetch(:pid)) do
            add_member_of(keywords.fetch(:member_of) { [] })
          end
          # A concession that when I make something it should be persisted.
          Persistence.add_to_cache(pid, self)
        end
      end

      class Collection < Document
      end

      class Work < Document
      end
    end
  end
end
