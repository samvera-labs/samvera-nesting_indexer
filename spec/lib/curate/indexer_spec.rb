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
    context 'a Diamond scenario' do
      before do
        Indexer::Persistence::Collection.new(pid: 'a')
        Indexer::Persistence::Collection.new(pid: 'b', member_of: %w(a))
        Indexer::Persistence::Collection.new(pid: 'c', member_of: %w(a))
        Indexer::Persistence::Work.new(pid: '1', member_of: %w(b c))
      end

      it 'should walk up the member_of relationships' do
        response = Indexer.reindex(pid: '1')
        expect(response.member_of).to eq(%w(b c))
        expect(response.transitive_member_of.sort).to eq(%w(a b c))
        expect(response.collection_members).to eq([])
        expect(response.transitive_collection_members).to eq([])

        indexed_collection_a = Indexer::Index::Query.find('a')
        expect(indexed_collection_a.transitive_member_of).to eq([])
        expect(indexed_collection_a.member_of).to eq([])
        expect(indexed_collection_a.collection_members.sort).to eq(%w(b c))
        expect(indexed_collection_a.transitive_collection_members.sort).to eq(%w(1 b c))

        indexed_collection_b = Indexer::Index::Query.find('b')
        expect(indexed_collection_b.transitive_member_of).to eq(%w(a))
        expect(indexed_collection_b.member_of).to eq(%w(a))
        expect(indexed_collection_b.collection_members).to eq(%w(1))
        expect(indexed_collection_b.transitive_collection_members).to eq(%w(1))

        indexed_collection_c = Indexer::Index::Query.find('c')
        expect(indexed_collection_c.transitive_member_of).to eq(%w(a))
        expect(indexed_collection_c.member_of).to eq(%w(a))
        expect(indexed_collection_c.collection_members).to eq(%w(1))
        expect(indexed_collection_c.transitive_collection_members).to eq(%w(1))
      end
    end

    context 'a Triangle scenario' do
      before do
        Indexer::Persistence::Collection.new(pid: 'a')
        Indexer::Persistence::Collection.new(pid: 'b', member_of: %w(a))
        Indexer::Persistence::Work.new(pid: '1', member_of: %w(a b))
      end

      it 'should walk up the member_of relationships' do
        response = Indexer.reindex(pid: '1')
        expect(response.member_of).to eq(%w(a b))
        expect(response.transitive_member_of.sort).to eq(%w(a b))
        expect(response.collection_members).to eq([])
        expect(response.transitive_collection_members).to eq([])

        indexed_collection_a = Indexer::Index::Query.find('a')
        expect(indexed_collection_a.transitive_member_of).to eq([])
        expect(indexed_collection_a.member_of).to eq([])
        expect(indexed_collection_a.collection_members.sort).to eq(%w(1 b))
        expect(indexed_collection_a.transitive_collection_members.sort).to eq(%w(1 b))

        indexed_collection_b = Indexer::Index::Query.find('b')
        expect(indexed_collection_b.transitive_member_of).to eq(%w(a))
        expect(indexed_collection_b.member_of).to eq(%w(a))
        expect(indexed_collection_b.collection_members).to eq(%w(1))
        expect(indexed_collection_b.transitive_collection_members).to eq(%w(1))
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
