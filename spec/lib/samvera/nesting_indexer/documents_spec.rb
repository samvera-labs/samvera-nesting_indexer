require 'spec_helper'

module Samvera
  module NestingIndexer
    module Documents
      RSpec.describe IndexDocument do
        let(:index_document) { described_class.new(id: 'a', parent_ids: 'b', pathnames: ['b/a'], ancestors: ['b']) }
        describe '#deepest_nested_depth' do
          subject { index_document.deepest_nested_depth }
          it { is_expected.to be_a(Integer) }
        end

        describe '#to_hash' do
          subject { index_document.to_hash }
          it { is_expected.to be_a(Hash) }
        end
      end
    end
  end
end
