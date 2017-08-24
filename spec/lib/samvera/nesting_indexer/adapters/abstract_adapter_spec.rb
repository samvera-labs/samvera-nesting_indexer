require 'spec_helper'
require 'samvera/nesting_indexer/adapters/abstract_adapter'
require 'samvera/nesting_indexer/adapters/interface_behavior_spec'

module Samvera
  module NestingIndexer
    module Adapters
      RSpec.describe AbstractAdapter do
        it_behaves_like 'a Samvera::NestingIndexer::Adapter'
        describe '.find_preservation_document_by(id:)' do
          subject { described_class.find_preservation_document_by(id: 1) }
          it 'requires implementation (see documentation)' do
            expect { subject }.to raise_error(NotImplementedError)
          end
        end

        describe '.find_index_document_by' do
          subject { described_class.find_index_document_by(id: 1) }
          it 'requires implementation (see documentation)' do
            expect { subject }.to raise_error(NotImplementedError)
          end
        end

        describe '.each_preservation_document' do
          subject { described_class.each_preservation_document }
          it 'requires implementation (see documentation)' do
            expect { subject }.to raise_error(NotImplementedError)
          end
        end

        describe '.each_child_document_of' do
          subject { described_class.each_child_document_of(document: double) }
          it 'requires implementation (see documentation)' do
            expect { subject }.to raise_error(NotImplementedError)
          end
        end

        describe '.write_document_attributes_to_index_layer' do
          subject { described_class.write_document_attributes_to_index_layer({}) }
          it 'requires implementation (see documentation)' do
            expect { subject }.to raise_error(NotImplementedError)
          end
        end
      end
    end
  end
end
