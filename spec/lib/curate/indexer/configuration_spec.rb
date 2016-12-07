require 'spec_helper'
require 'curate/indexer/exceptions'
require 'curate/indexer/adapters/in_memory_adapter'
require 'curate/indexer/adapters/abstract_adapter'

module Curate
  module Indexer
    RSpec.describe Configuration do
      let(:configuration) { described_class.new }
      context '#adapter' do
        context 'with explicit configuring' do
          subject { configuration.tap { |config| config.adapter = Adapters::AbstractAdapter } }
          it { is_expected.to_not eq(Adapters::InMemoryAdapter) }
        end
        context 'with improper configuration' do
          it 'will raise an exception' do
            expect { configuration.tap { |config| config.adapter = :bogus_adapter } }.to(
              raise_error(Exceptions::AdapterConfigurationError)
            )
          end
        end
        context 'without explicit configuring' do
          subject { configuration.adapter }
          it { is_expected.to eq(Adapters::InMemoryAdapter) }
        end
      end
    end
  end
end
