require 'spec_helper'
require 'samvera/indexer/railtie'

module Samvera
  module Indexer
    RSpec.describe Railtie do
      context '.config' do
        let(:railtie) { described_class }
        let(:config) { railtie.config }
        context '.eager_load_namespaces' do
          subject { config.eager_load_namespaces }
          it { is_expected.to_not include(Samvera::Indexer) }
        end
        context '.to_prepare_blocks' do
          subject { config.to_prepare_blocks }
          it { is_expected.to_not be_empty }
          it 'will configure the indexer when called' do
            expect(Samvera::Indexer).to receive(:configure!)
            config.to_prepare_blocks.each(&:call)
          end
        end
      end
    end
  end
end
