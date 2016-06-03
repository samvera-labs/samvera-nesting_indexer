require 'spec_helper'
require 'curate/indexer'
require 'support/compact_graph_indexer'
require 'support/individual_node_indexer'

RSpec.describe 'reindexing via a tree' do
  [
    {
      previous: { a: [], b: [:a], c: [] },
      event: { c: [:b, :a] },
      expected: { a: { b: { c: {} }, c: {} } }
    }, {
      previous: { a: [], b: [], c: [], d: [:a, :b] },
      event: { c: [:a, :b] },
      expected: { a: { d: {}, c: {} }, b: { d: {}, c: {} } }
    }, {
      # Adding a new node to the graph
      previous: { a: [], b: [:a], c: [:a], d: [:b, :c] },
      event: { e: [:a] },
      expected: { a: { e: {}, b: { d: {} }, c: { d: {} } } }
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
  # the value for the key represents the member_of relationship.
  def build_previous_index(previous_entries)
    IndividualNodeIndexer.call(previous_entries)
  end

  def reindex_for_events(events)
    events.each_pair do |pid, member_of|
      Curate::Indexer::Persistence.find_or_build(pid).add_member_of(*member_of)
      Curate::Indexer.reindex(pid: pid)
    end
  end

  def build_snapshot_of_index
    Curate::Indexer::Index::Query.cache.each_with_object({}) do |(pid, document), mem|
      mem[pid] = Curate::Indexer::Index::Document.new(pid: pid) do
        add_member_of(document.member_of)
        add_transitive_member_of(document.transitive_member_of)
        add_members(document.members)
        add_transitive_members(document.transitive_members)
      end
    end
  end

  def clear_all_caches
    CompactGraphIndexer.clear_all_caches!
  end

  def build_index_from_compact_graph_format(compact_graph)
    CompactGraphIndexer.call(compact_graph)
    Curate::Indexer::Index::Query.cache
  end
end
