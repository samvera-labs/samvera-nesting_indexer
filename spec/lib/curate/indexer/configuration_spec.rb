require 'spec_helper'
require 'curate/indexer/in_memory_adapter'

module Curate
  module Indexer
    RSpec.describe Configuration do
      let(:configuration) { described_class.new }
      context '#adapter' do
        context 'with explicit configuring' do
          subject { configuration.tap { |config| config.adapter = :mock_adapter } }
          it { is_expected.to_not eq(InMemoryAdapter) }
        end
        context 'without explicit configuring' do
          subject { configuration.adapter }
          it { is_expected.to eq(InMemoryAdapter) }
        end
      end
    end
  end
end
