require 'spec_helper'
require 'rspec/its'

module Curate
  RSpec.describe Indexer do
    before do
      Indexer::Index::Query.clear_cache!
      Indexer::Persistence.clear_cache!
      Indexer::Processing.clear_cache!
    end

    context 'Graph Scenario 1' do
      before do
        Indexer::Persistence::Collection.new(pid: 'a')
        Indexer::Persistence::Collection.new(pid: 'b', member_of: %w(a d))
        Indexer::Persistence::Collection.new(pid: 'c', member_of: %w(b))
        Indexer::Persistence::Collection.new(pid: 'd')
        Indexer::Persistence::Collection.new(pid: 'e')
        Indexer::Persistence::Collection.new(pid: 'f')
        Indexer::Persistence::Collection.new(pid: 'g')
        Indexer::Persistence::Work.new(pid: '1', member_of: %w(a e))
        Indexer::Persistence::Work.new(pid: '2', member_of: %w(b))
        Indexer::Persistence::Work.new(pid: '3', member_of: %w(c))
        Indexer::Persistence::Work.new(pid: '4', member_of: %w(d))
        Indexer::Persistence::Work.new(pid: '5', member_of: %w(f))
        Indexer::Persistence::Work.new(pid: '6')
      end

      context 'when building index for Work 2' do
        context 'and we have a max_depth violation' do
          it 'should raise an exception' do
            expect { Indexer.reindex(pid: '2', max_level: 1) }.to raise_error(Indexer::ReindexingReachedMaxLevelError)
          end
        end
        context 'and we added something to the object' do
          before do
            %w(1 2 3 4 5 6).each do |pid|
              Indexer.reindex(pid: pid)
            end
            # Because the above reindexing creates caches that need invalidating
            Indexer::Processing.clear_cache!
          end
          it 'should amend the expected graph' do
            Indexer::Persistence.find('2').add_member_of('c')
            response = Indexer.reindex(pid: '2')
            expect(response.member_of).to eq(%w(b c))
            expect(response.transitive_member_of.sort).to eq(%w(a b c d))
            expect(response.collection_members).to eq([])
            expect(response.transitive_collection_members).to eq([])
          end
        end
        context 'and the existing index is not empty' do
          before do
            %w(1 3 4 5 6).each do |pid|
              Indexer.reindex(pid: pid)
            end
            # Because the above reindexing creates caches that need invalidating
            Indexer::Processing.clear_cache!
          end
          it 'should walk up the member_of relationships and merge with existing index' do
            response = Indexer.reindex(pid: '2')
            expect(response.member_of).to eq(['b'])
            expect(response.transitive_member_of).to eq(%w(b a d))
            expect(response.collection_members).to eq([])
            expect(response.transitive_collection_members).to eq([])

            indexed_collection_b = Indexer::Index::Query.find('b')
            expect(indexed_collection_b.transitive_member_of).to eq(%w(a d))
            expect(indexed_collection_b.member_of).to eq(%w(a d))
            expect(indexed_collection_b.collection_members).to eq(%w(c 2))
            expect(indexed_collection_b.transitive_collection_members.sort).to eq(%w(c 3 2).sort)

            indexed_collection_a = Indexer::Index::Query.find('a')
            expect(indexed_collection_a.transitive_member_of).to eq([])
            expect(indexed_collection_a.member_of).to eq([])
            expect(indexed_collection_a.collection_members).to eq(%w(1 b))
            expect(indexed_collection_a.transitive_collection_members.sort).to eq(%w(1 2 3 b c))

            indexed_collection_d = Indexer::Index::Query.find('d')
            expect(indexed_collection_d.transitive_member_of).to eq([])
            expect(indexed_collection_d.member_of).to eq([])
            expect(indexed_collection_d.collection_members).to eq(%w(b 4))
            expect(indexed_collection_d.transitive_collection_members.sort).to eq(%w(2 3 4 b c))
          end
        end
        context 'and the index is empty' do
          it 'should walk up the member_of relationships' do
            response = Indexer.reindex(pid: '2')
            expect(response.member_of).to eq(['b'])
            expect(response.transitive_member_of).to eq(%w(b a d))
            expect(response.collection_members).to eq([])
            expect(response.transitive_collection_members).to eq([])

            indexed_collection_b = Indexer::Index::Query.find('b')
            expect(indexed_collection_b.transitive_member_of).to eq(%w(a d))
            expect(indexed_collection_b.member_of).to eq(%w(a d))
            expect(indexed_collection_b.collection_members).to eq(%w(2))
            expect(indexed_collection_b.transitive_collection_members).to eq(%w(2))

            indexed_collection_a = Indexer::Index::Query.find('a')
            expect(indexed_collection_a.transitive_member_of).to eq([])
            expect(indexed_collection_a.member_of).to eq([])
            expect(indexed_collection_a.collection_members).to eq(%w(b))
            expect(indexed_collection_a.transitive_collection_members.sort).to eq(%w(2 b))

            indexed_collection_d = Indexer::Index::Query.find('d')
            expect(indexed_collection_d.transitive_member_of).to eq([])
            expect(indexed_collection_d.member_of).to eq([])
            expect(indexed_collection_d.collection_members).to eq(%w(b))
            expect(indexed_collection_d.transitive_collection_members.sort).to eq(%w(2 b))
          end
        end
      end
    end

    # An assistive class for verification of graphs
    class Verifier
      attr_accessor :pid, :collection_members, :transitive_collection_members, :member_of, :transitive_member_of
      def initialize(pid, options = {})
        self.pid = pid
        self.collection_members = options.fetch(:collection_members) { [] }
        self.member_of = options.fetch(:member_of) { [] }
        # A concession that transitive relationships are additive to the "direct" relationship
        self.transitive_collection_members = (options.fetch(:transitive_collection_members) { [] } + collection_members).uniq
        self.transitive_member_of = (options.fetch(:transitive_member_of) { [] } + member_of).uniq
      end

      def verified?
        @item = Indexer::Index::Query.find(pid)
        [:collection_members, :transitive_collection_members, :member_of, :transitive_member_of].each do |method_name|
          return false unless @item.public_send(method_name).sort == send(method_name).sort
        end
        true
      end
    end

    context 'a Diamond scenario' do
      let(:persistence) do
        { "a" => [], "b" => %w(a), "c" => %w(a), "1" => %w(b c) }
      end
      let(:expected) do
        [
          Verifier.new('1', member_of: %w(b c), transitive_member_of: %w(a b c)),
          Verifier.new('a', collection_members: %w(b c), transitive_collection_members: %w(1 b c)),
          Verifier.new('b', member_of: %w(a), collection_members: %w(1)),
          Verifier.new('c', member_of: %w(a), collection_members: %w(1))
        ]
      end
      before do
        persistence.each_pair do |pid, member_of|
          Indexer::Persistence::Document.new(pid: pid, member_of: member_of)
        end
      end

      it 'should walk up the member_of relationships' do
        Indexer.reindex(pid: '1')
        expected.each do |item|
          expect(item).to be_verified
        end
      end
    end

    context 'a Triangle scenario' do
      let(:persistence) do
        { "a" => [], "b" => %w(a), "1" => %w(a b) }
      end
      before do
        persistence.each_pair do |pid, member_of|
          Indexer::Persistence::Document.new(pid: pid, member_of: member_of)
        end
      end

      let(:expected) do
        [
          Verifier.new('1', member_of: %w(a b)),
          Verifier.new('a', collection_members: %w(1 b)),
          Verifier.new('b', member_of: %w(a), collection_members: %w(1))
        ]
      end

      it 'should walk up the member_of relationships' do
        Indexer.reindex(pid: '1')
        expected.each do |item|
          expect(item).to be_verified
        end
      end
    end
  end

  RSpec.describe Indexer::Processing do
    context '.create_processing_document_for' do
      let(:pid) { 'A' }
      let(:level) { 4 }
      let(:persisted_document) { Indexer::Persistence::Work.new(pid: pid, member_of: %w(B)) }
      let(:indexed_document) do
        Indexer::Index::Document.new(pid: pid) do
          add_transitive_member_of %w(B C)
          add_transitive_collection_members %w(E F)
          add_collection_members %w(E)
        end
      end
      let(:persistence_finder) { double('Persistence Finder', call: persisted_document) }
      let(:index_finder) { double('Index Finder', call: indexed_document) }
      subject do
        described_class.find_or_create_processing_document_for(
          pid: pid,
          level: level,
          persistence_finder: persistence_finder,
          index_finder: index_finder
        )
      end
      its(:member_of) { is_expected.to eq(%w(B)) }
      its(:transitive_member_of) { is_expected.to eq(%w(B C)) }
      its(:transitive_collection_members) { is_expected.to eq(%w(E F)) }
      its(:collection_members) { is_expected.to eq(%w(E)) }
    end
  end
end
