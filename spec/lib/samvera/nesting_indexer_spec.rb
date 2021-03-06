require 'spec_helper'
require 'samvera/nesting_indexer'

describe Samvera::NestingIndexer do
  it { is_expected.to respond_to(:config) }
  it { is_expected.to respond_to(:configuration) }

  describe '.configure' do
    before do
      Object.send(:remove_const, :Rails) if defined?(Rails)
    end
    describe 'without Rails defined' do
      it 'will call the configuration block' do
        expect { |b| described_class.configure(&b) }.to yield_control
      end
    end

    describe 'with Rails defined' do
      before do
        module Rails
        end
      end
      after do
        Object.send(:remove_const, :Rails)
      end
      it 'will not call the configuration block immediately but instead rely on the Samvera::NestingIndexer::Railtie' do
        expect { |b| described_class.configure(&b) }.to_not yield_control
      end
    end
  end
end
