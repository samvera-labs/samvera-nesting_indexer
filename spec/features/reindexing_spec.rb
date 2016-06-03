require 'spec_helper'
require 'curate/indexer'
require 'support/hash_indexer'

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
  # the value for the key represents the member_of relationship. See the example
  # below:
  #
  # ```ruby
  # { a: [], b: [:a], c: [:b] }
  # ```
  #
  # * Node `:a` has:
  #   - members: `[:b]`
  #   - transitive_members: `[:b, :c]`
  #   - member_of: `[]`
  #   - transitive_member_of: `[]`
  # * Node `:b` has:
  #   - members: `[:c]`
  #   - transitive_members: `[:c]`
  #   - member_of: `[:a]`
  #   - transitive_member_of: `[:a]`
  # * Node `:c` has:
  #   - members: `[]`
  #   - transitive_members: `[]`
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
    HashIndexer.clear_all_caches!
  end

  # The compact graph format is a means of expressing members relationships. Note the example below:
  #
  # ```ruby
  #   { a: { b: { c: {} } } }
  # ```
  #
  # * Node `:a` has:
  #   - members: `[:b]`
  #   - transitive_members: `[:b, :c]`
  #   - member_of: `[]`
  #   - transitive_member_of: `[]`
  # * Node `:b` has:
  #   - members: `[:c]`
  #   - transitive_members: `[:c]`
  #   - member_of: `[:a]`
  #   - transitive_member_of: `[:a]`
  # * Node `:c` has:
  #   - members: `[]`
  #   - transitive_members: `[]`
  #   - member_of: `[:b]`
  #   - transitive_member_of: `[:b]``
  def build_index_from_compact_graph_format(compact_graph)
    HashIndexer.call(compact_graph)
    Curate::Indexer::Index::Query.cache
  end
end
