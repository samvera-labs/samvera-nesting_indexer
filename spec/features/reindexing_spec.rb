require 'spec_helper'
require 'curate/indexer'
RSpec.describe 'reindexing via a tree' do
  # A recursive indexer for a compact hash representation of the collection graph.
  module HashIndexer
    def self.call(graph, member_of_document = nil, rebuilder = nil)
      return true if end_of_recursion?(graph, rebuilder)
      graph.each_pair do |key, subgraph|
        document = Curate::Indexer::Index::Query.find(key)
        rebuilder = associate(document, member_of_document, rebuilder)
        call(subgraph, document, rebuilder)
      end
    end

    def self.end_of_recursion?(graph, rebuilder)
      return false unless graph.empty?
      Curate::Indexer::Processing.clear_cache!
      rebuilder.send(:cache).each do |key, _document|
        Curate::Indexer.reindex(pid: key)
      end
      true
    end

    def self.associate(document, member_of_document, rebuilder)
      persisted_document = Curate::Indexer::Persistence.find(document.pid) do
        Curate::Indexer::Persistence::Document.new(pid: document.pid)
      end
      rebuilder ||= Curate::Indexer::Index.new_rebuilder(requested_for: document)
      if member_of_document
        persisted_document.add_member_of(member_of_document.pid)
        rebuilder.associate(document: document, member_of_document: member_of_document)
      end
      rebuilder
    end
  end
  [
    {
      previous: { a: [], b: [:a], c: [] },
      event: { c: [:b, :a] },
      expected: { a: { b: { c: {} }, c: {} } }
    }, {
      previous: { a: [], b: [], c: [], d: [:a, :b] },
      event: { c: [:a, :b] },
      expected: { a: { d: {}, c: {} }, b: { d: {}, c: {} }, c: {}, d: {} }
    }
  ].each_with_index do |config, index|
    context "Scenario #{index}" do
      before do
        Curate::Indexer::Index::Query.clear_cache!
        Curate::Indexer::Persistence.clear_cache!
        Curate::Indexer::Processing.clear_cache!
      end
      it "should be correct" do
        config.fetch(:previous).each_pair do |pid, member_of|
          Curate::Indexer::Persistence::Document.new(pid: pid, member_of: member_of)
          Curate::Indexer.reindex(pid: pid)
        end
        Curate::Indexer::Processing.clear_cache!
        config.fetch(:event).each_pair do |pid, member_of|
          Curate::Indexer::Persistence.find(pid).add_member_of(*member_of)
          Curate::Indexer.reindex(pid: pid)
        end
        local_cache = Curate::Indexer::Index::Query.cache.each_with_object({}) do |(pid, document), mem|
          mem[pid] = Curate::Indexer::Index::Document.new(pid: pid) do
            add_member_of(document.member_of)
            add_transitive_member_of(document.transitive_member_of)
            add_collection_members(document.collection_members)
            add_transitive_collection_members(document.transitive_collection_members)
          end
        end

        Curate::Indexer::Index::Query.clear_cache!
        Curate::Indexer::Persistence.clear_cache!
        Curate::Indexer::Processing.clear_cache!

        HashIndexer.call(config.fetch(:expected))
        expect(local_cache).to eq(Curate::Indexer::Index::Query.cache)
      end
    end
  end
end
