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
      let!(:collection_a) { Indexer::Persistence::Collection.new(pid: 'a') }
      let!(:collection_b) { Indexer::Persistence::Collection.new(pid: 'b', is_member_of: ['a', 'd']) }
      let!(:collection_c) { Indexer::Persistence::Collection.new(pid: 'c', is_member_of: ['b']) }
      let!(:collection_d) { Indexer::Persistence::Collection.new(pid: 'd') }
      let!(:collection_e) { Indexer::Persistence::Collection.new(pid: 'e') }
      let!(:collection_f) { Indexer::Persistence::Collection.new(pid: 'f') }
      let!(:collection_g) { Indexer::Persistence::Collection.new(pid: 'g') }
      let!(:work_1) { Indexer::Persistence::Work.new(pid: '1', is_member_of: ['a', 'e']) }
      let!(:work_2) { Indexer::Persistence::Work.new(pid: '2', is_member_of: ['b']) }
      let!(:work_3) { Indexer::Persistence::Work.new(pid: '3', is_member_of: ['c']) }
      let!(:work_4) { Indexer::Persistence::Work.new(pid: '4', is_member_of: ['d']) }
      let!(:work_5) { Indexer::Persistence::Work.new(pid: '5', is_member_of: ['f']) }
      let!(:work_6) { Indexer::Persistence::Work.new(pid: '6') }

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
            work_2.add_is_member_of('c')
            response = Indexer.reindex(pid: '2')
            expect(response.is_member_of).to eq(%w(b c))
            expect(response.is_transitive_member_of.sort).to eq(%w(a b c d))
            expect(response.has_collection_members).to eq([])
            expect(response.has_transitive_collection_members).to eq([])
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
          it 'should walk up the is_member_of relationships and merge with existing index' do
            response = Indexer.reindex(pid: '2')
            expect(response.is_member_of).to eq(['b'])
            expect(response.is_transitive_member_of).to eq(%w(b a d))
            expect(response.has_collection_members).to eq([])
            expect(response.has_transitive_collection_members).to eq([])

            indexed_collection_b = Indexer::Index::Query.find('b')
            expect(indexed_collection_b.is_transitive_member_of).to eq(%w(a d))
            expect(indexed_collection_b.is_member_of).to eq(%w(a d))
            expect(indexed_collection_b.has_collection_members).to eq(%w(c 2))
            expect(indexed_collection_b.has_transitive_collection_members.sort).to eq(%w(c 3 2).sort)

            indexed_collection_a = Indexer::Index::Query.find('a')
            expect(indexed_collection_a.is_transitive_member_of).to eq([])
            expect(indexed_collection_a.is_member_of).to eq([])
            expect(indexed_collection_a.has_collection_members).to eq(%w(1 b))
            expect(indexed_collection_a.has_transitive_collection_members.sort).to eq(%w(1 2 3 b c))

            indexed_collection_d = Indexer::Index::Query.find('d')
            expect(indexed_collection_d.is_transitive_member_of).to eq([])
            expect(indexed_collection_d.is_member_of).to eq([])
            expect(indexed_collection_d.has_collection_members).to eq(%w(b 4))
            expect(indexed_collection_d.has_transitive_collection_members.sort).to eq(%w(2 3 4 b c))
          end
        end
        context 'and the index is empty' do
          it 'should walk up the is_member_of relationships' do
            response = Indexer.reindex(pid: '2')
            expect(response.is_member_of).to eq(['b'])
            expect(response.is_transitive_member_of).to eq(%w(b a d))
            expect(response.has_collection_members).to eq([])
            expect(response.has_transitive_collection_members).to eq([])

            indexed_collection_b = Indexer::Index::Query.find('b')
            expect(indexed_collection_b.is_transitive_member_of).to eq(%w(a d))
            expect(indexed_collection_b.is_member_of).to eq(%w(a d))
            expect(indexed_collection_b.has_collection_members).to eq(%w(2))
            expect(indexed_collection_b.has_transitive_collection_members).to eq(%w(2))

            indexed_collection_a = Indexer::Index::Query.find('a')
            expect(indexed_collection_a.is_transitive_member_of).to eq([])
            expect(indexed_collection_a.is_member_of).to eq([])
            expect(indexed_collection_a.has_collection_members).to eq(%w(b))
            expect(indexed_collection_a.has_transitive_collection_members.sort).to eq(%w(2 b))

            indexed_collection_d = Indexer::Index::Query.find('d')
            expect(indexed_collection_d.is_transitive_member_of).to eq([])
            expect(indexed_collection_d.is_member_of).to eq([])
            expect(indexed_collection_d.has_collection_members).to eq(%w(b))
            expect(indexed_collection_d.has_transitive_collection_members.sort).to eq(%w(2 b))
          end
        end
      end
    end
  end

  RSpec.describe Indexer::Processing do
    context '.create_processing_document_for' do
      let(:pid) { 'A' }
      let(:level) { 4 }
      let(:persisted_document) { Indexer::Persistence::Work.new(pid: pid, is_member_of: ['B']) }
      let(:indexed_document) do
        Indexer::Index::Document.new(pid: pid) do |doc|
          doc.is_transitive_member_of = ['B', 'C']
          doc.has_transitive_collection_members = ['E', 'F']
          doc.has_collection_members = ['E']
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
      its(:is_member_of) { is_expected.to eq(['B']) }
      its(:is_transitive_member_of) { is_expected.to eq(['B', 'C']) }
      its(:has_transitive_collection_members) { is_expected.to eq(['E', 'F']) }
      its(:has_collection_members) { is_expected.to eq(['E']) }
    end
  end
end
