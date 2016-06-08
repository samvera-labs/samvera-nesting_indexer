require 'dry-initializer'
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
        extend Dry::Initializer::Mixin
        option :pid, type: Types::Coercible::String
        option :parents, type: Types::Coercible::Array

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
