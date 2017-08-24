require 'spec_helper'
require 'samvera/nesting_indexer/adapters/abstract_adapter'

module Samvera
  module NestingIndexer
    module Adapters
      RSpec.describe AbstractAdapter do
        AbstractAdapter.methods(false).each do |method_name|
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
