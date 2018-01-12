require 'spec_helper'
require 'samvera/nesting_indexer/adapters/in_memory_adapter'
require 'samvera/nesting_indexer/adapters/interface_behavior_spec'

module Samvera
  module NestingIndexer
    module Adapters
      RSpec.describe InMemoryAdapter do
        it_behaves_like 'a Samvera::NestingIndexer::Adapter'

        # In place to appease code coverage
        describe '#write_document_attributes_to_index_layer' do
          it 'is a deprecated method' do
            expect do
              described_class.write_document_attributes_to_index_layer(id: 'a', pathnames: ['a'], ancestors: [], deepest_nested_depth: 1, parent_ids: [])
            end.not_to raise_error
          end
        end
      end
    end
  end
end
