require 'spec_helper'
require 'curate/indexer/adapters/in_memory_adapter'

module Curate
  module Indexer
    RSpec.describe Configuration do
      let(:configuration) { described_class.new }
      context '#adapter' do
        context 'with explicit configuring' do
          subject { configuration.tap { |config| config.adapter = :mock_adapter } }
          it { is_expected.to_not eq(Adapters::InMemoryAdapter) }
        end
        context 'without explicit configuring' do
          subject { configuration.adapter }
          it { is_expected.to eq(Adapters::InMemoryAdapter) }
        end
      end
    end
  end
end
