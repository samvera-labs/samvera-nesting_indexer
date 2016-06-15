require 'spec_helper'
require 'curate/indexer/adapters'

module Curate
  module Indexer
    module Adapters
      RSpec.describe AbstractAdapter do
        [
          'find_preservation_document_by',
          'find_index_document_by',
          'each_preservation_document',
          'each_child_document_of',
          'write_document_attributes_to_index_layer'
        ].each do |method_name|
          context ".#{method_name}" do
            it 'requires implementation (see documentation)' do
              expect { described_class.public_send(method_name) }.to raise_error(NotImplementedError)
            end
          end
        end
      end
    end
  end
end
