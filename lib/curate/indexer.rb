require "curate/indexer/version"
require 'dry-types'

module Curate
  # Responsible for the indexing strategy of related objects
  module Indexer
    # Providing a module to contain Type coercion regarding indexing
    module Types
      include Dry::Types.module
    end
  end
end
