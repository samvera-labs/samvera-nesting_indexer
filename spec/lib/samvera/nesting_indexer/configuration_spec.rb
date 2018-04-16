require 'spec_helper'
require 'samvera/nesting_indexer/exceptions'
require 'samvera/nesting_indexer/adapters/in_memory_adapter'
require 'samvera/nesting_indexer/adapters/abstract_adapter'

module Samvera
  module NestingIndexer
    RSpec.describe Configuration do
      let(:configuration) { described_class.new }
      context '#maximum_nesting_depth' do
        subject { configuration.maximum_nesting_depth }
        it { is_expected.to be_a(Integer) }
      end

      describe '#logger' do
        before { Object.send(:remove_const, :Rails) if defined?(Rails) }
        describe 'by default' do
          describe 'with Rails defined' do
            before do
              # rubocop:disable Style/ClassAndModuleChildren
              module ::Rails
                def self.logger
                  :logger
                end
              end
              # rubocop:enable Style/ClassAndModuleChildren
            end
            after do
              Object.send(:remove_const, :Rails) if defined?(Rails)
            end
            it 'uses the existing Rails logger' do
              subject = described_class.new
              expect(subject.logger).to eq(Rails.logger)
            end
          end
          describe 'without Rails defined' do
            it 'uses a simple Logger that writes to STDOUT' do
              subject = described_class.new
              expect(defined?(Rails)).to be_falsey
              expect(subject.logger).to be_a(Logger)
            end
          end
        end
        it 'can be overridden' do
          logger = double('logger')
          subject = described_class.new
          expect { subject.logger = logger }.to change { subject.logger }.to(logger)
        end
      end

      describe '#solr_field_name_for_storing_parent_ids' do
        subject { configuration.solr_field_name_for_storing_parent_ids }

        describe 'when set' do
          before { configuration.solr_field_name_for_storing_parent_ids = :the_key }

          it { is_expected.to be_a(String) }
        end

        describe 'when not set' do
          it 'raises Exceptions::SolrKeyConfigurationError' do
            expect { subject }.to raise_error(Exceptions::SolrKeyConfigurationError)
          end
        end
      end

      describe '#solr_field_name_for_storing_ancestors' do
        subject { configuration.solr_field_name_for_storing_ancestors }

        describe 'when set' do
          before { configuration.solr_field_name_for_storing_ancestors = :the_key }

          it { is_expected.to be_a(String) }
        end

        describe 'when not set' do
          it 'raises Exceptions::SolrKeyConfigurationError' do
            expect { subject }.to raise_error(Exceptions::SolrKeyConfigurationError)
          end
        end
      end

      describe '#solr_field_name_for_storing_pathnames' do
        subject { configuration.solr_field_name_for_storing_pathnames }

        describe 'when set' do
          before { configuration.solr_field_name_for_storing_pathnames = :the_key }

          it { is_expected.to be_a(String) }
        end

        describe 'when not set' do
          it 'raises Exceptions::SolrKeyConfigurationError' do
            expect { subject }.to raise_error(Exceptions::SolrKeyConfigurationError)
          end
        end
      end

      describe '#solr_field_name_for_deepest_nested_depth' do
        subject { configuration.solr_field_name_for_deepest_nested_depth }

        describe 'when set' do
          before { configuration.solr_field_name_for_deepest_nested_depth = :the_key }

          it { is_expected.to be_a(String) }
        end

        describe 'when not set' do
          it 'raises Exceptions::SolrKeyConfigurationError' do
            expect { subject }.to raise_error(Exceptions::SolrKeyConfigurationError)
          end
        end
      end

      context '#adapter' do
        it 'is not set when initialized (and thus does not send a logging message)' do
          expect do
            subject.adapter = Adapters::AbstractAdapter
          end.to change { subject.instance_variable_get("@adapter") }.from(nil).to(Adapters::AbstractAdapter)
        end

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
