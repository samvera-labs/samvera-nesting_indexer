require 'curate/indexer/storage_module'

module Curate
  module Indexer
    # A module responsible for containing the "preservation interface" logic.
    # In the case of CurateND, there will need to be an adapter to get a Fedora
    # object coerced into a Curate::Indexer::Preservation::Document
    module Preservation
      # A simplified document that reflects the necessary attributes for re-indexing
      # the children of Fedora objects.
      class Document
        def initialize(keywords = {})
          @pid = keywords.fetch(:pid).to_s
          @parent_pids = Array(keywords.fetch(:parent_pids))
        end
        attr_reader :pid, :parent_pids

        def write
          Storage.write(self)
        end
      end
      # :nodoc:
      module Storage
        extend StorageModule
      end
    end
  end
end
