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
    end
  end
end
