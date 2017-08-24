require 'spec_helper'
require 'samvera/nesting_indexer/adapters/in_memory_adapter'
require 'samvera/nesting_indexer/adapters/interface_behavior_spec'

module Samvera
  module NestingIndexer
    module Adapters
      RSpec.describe InMemoryAdapter do
        it_behaves_like 'a Samvera::NestingIndexer::Adapter'
      end
    end
  end
end
