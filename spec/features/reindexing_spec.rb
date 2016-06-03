require 'spec_helper'
require 'curate/indexer'
RSpec.describe 'reindexing via a tree' do
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
        clear_all_caches
      end
      it "should be correct" do
        build_previous_index(config.fetch(:previous))
        reindex_for_events(config.fetch(:event))
        index_snapshop = build_snapshot_of_index
        clear_all_caches
        expected_index_snap_shot = build_index_from_compact_graph_format(config.fetch(:expected))
        expect(index_snapshop).to eq(expected_index_snap_shot)
      end
    end
  end

  private

  # The previous_entries hash format is as follows: the key represents the node,
  # the value for the key represents the member_of relationship. See the example
  # below:
  #
  # ```ruby
  # { a: [], b: [:a], c: [:b] }
  # ```
  #
  # * Node `:a` has:
  #   - collection_members: `[:b]`
  #   - transitive_collection_members: `[:b, :c]`
  #   - member_of: `[]`
  #   - transitive_member_of: `[]`
  # * Node `:b` has:
  #   - collection_members: `[:c]`
  #   - transitive_collection_members: `[:c]`
  #   - member_of: `[:a]`
  #   - transitive_member_of: `[:a]`
  # * Node `:c` has:
  #   - collection_members: `[]`
  #   - transitive_collection_members: `[]`
  #   - member_of: `[:b]`
  #   - transitive_member_of: `[:b]``
  def build_previous_index(previous_entries)
    previous_entries.each_pair do |pid, member_of|
      Curate::Indexer::Persistence::Document.new(pid: pid, member_of: member_of)
      Curate::Indexer.reindex(pid: pid)
    end
    # If we don't clear the processing cache, we'll be obliterating the previous work
    Curate::Indexer::Processing.clear_cache!
  end

  def reindex_for_events(events)
    events.each_pair do |pid, member_of|
      Curate::Indexer::Persistence.find(pid).add_member_of(*member_of)
      Curate::Indexer.reindex(pid: pid)
    end
  end

  def build_snapshot_of_index
    Curate::Indexer::Index::Query.cache.each_with_object({}) do |(pid, document), mem|
      mem[pid] = Curate::Indexer::Index::Document.new(pid: pid) do
        add_member_of(document.member_of)
        add_transitive_member_of(document.transitive_member_of)
        add_collection_members(document.collection_members)
        add_transitive_collection_members(document.transitive_collection_members)
      end
    end
  end

  def clear_all_caches
    Curate::Indexer::Index::Query.clear_cache!
    Curate::Indexer::Persistence.clear_cache!
    Curate::Indexer::Processing.clear_cache!
  end

  # The compact graph format is a means of expressing collection_members relationships. Note the example below:
  #
  # ```ruby
  #   { a: { b: { c: {} } } }
  # ```
  #
  # * Node `:a` has:
  #   - collection_members: `[:b]`
  #   - transitive_collection_members: `[:b, :c]`
  #   - member_of: `[]`
  #   - transitive_member_of: `[]`
  # * Node `:b` has:
  #   - collection_members: `[:c]`
  #   - transitive_collection_members: `[:c]`
  #   - member_of: `[:a]`
  #   - transitive_member_of: `[:a]`
  # * Node `:c` has:
  #   - collection_members: `[]`
  #   - transitive_collection_members: `[]`
  #   - member_of: `[:b]`
  #   - transitive_member_of: `[:b]``
  def build_index_from_compact_graph_format(compact_graph)
    HashIndexer.call(compact_graph)
    Curate::Indexer::Index::Query.cache
  end

  # A recursive indexer for a compact hash representation of the collection graph.
  module HashIndexer
    # This is an non-optimized index builder for generating the index based on
    # hash entries.
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
end
