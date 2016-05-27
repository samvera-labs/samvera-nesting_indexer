require 'set'
require 'curate/indexer/caching_module'

module Curate
  module Indexer
    # Responsible for being a layer between Fedora and the heavy lifting of the
    # reindexing processor. It has aspects that will need to change.
    module Persistence
      extend CachingModule

      # This is a disposable intermediary between Fedora and the processing system for reindexing.
      # I believe it is a good idea to keep separation from the persistence layer and the processing.
      #
      # Unlike the IndexingDocument, the Persistence Document should only have the direct relationship
      # information.
      # @see Curate::Indexer::IndexingDocument
      class Document
        attr_reader :pid
        def initialize(keywords = {})
          self.pid = keywords.fetch(:pid)
          self.member_of = keywords.fetch(:member_of) { [] }
          # A concession that when I make something it should be persisted.
          Persistence.add_to_cache(pid, self)
        end

        def member_of
          @member_of.to_a
        end

        def add_member_of(*pids)
          @member_of += pids.flatten.compact
        end

        private

        attr_writer :pid
        def member_of=(*input)
          # I'd prefer Array.wrap, but I'm assuming we won't have a DateTime object
          @member_of = Set.new(input.flatten.compact)
        end
      end

      class Collection < Document
      end

      class Work < Document
      end
    end
  end
end
