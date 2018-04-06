require 'spec_helper'
require 'samvera/nesting_indexer'
require 'samvera/nesting_indexer/exceptions'
require 'samvera/nesting_indexer/adapters'
require 'support/feature_spec_support_methods'

# :nodoc:
module Samvera
  module NestingIndexer
    RSpec.describe 'Reindex id and descendants' do
      include Support::FeatureSpecSupportMethods
      before do
        NestingIndexer.adapter.clear_cache!
      end

      context "non-Cycle graphs" do
        [
          {
            name: 'A graph without parents',
            starting_graph: {
              parent_ids: { a: [], b: [], c: [] },
              ancestors: { a: [], b: [], c: [] },
              pathnames: { a: ['a'], b: ['b'], c: ['c'] }
            },
            preservation_document_attributes_to_update: { id: :d, parent_ids: [] },
            ending_graph: {
              parent_ids: { a: [], b: [], c: [], d: [] },
              ancestors: { a: [], b: [], c: [], d: [] },
              pathnames: { a: ['a'], b: ['b'], c: ['c'], d: ['d'] }
            }
          }, {
            name: 'A semi-complicated graph with diamonds and triangle relationships',
            starting_graph: {
              parent_ids: { a: [], b: ['a'], c: ['a', 'b'], d: ['c', 'e'], e: ['b'] },
              ancestors: { a: [], b: ['a'], c: ['a/b', 'a'], d: ['a', 'a/b', 'a/b/c', 'a/b/e', 'a/c'], e: ['a', 'a/b'] },
              pathnames: { a: ['a'], b: ['a/b'], c: ['a/c', 'a/b/c'], d: ['a/c/d', 'a/b/c/d', 'a/b/e/d'], e: ['a/b/e'] }
            },
            preservation_document_attributes_to_update: { id: :c, parent_ids: ['a'] },
            ending_graph: {
              parent_ids: { a: [], b: ['a'], c: ['a'], d: ['c', 'e'], e: ['b'] },
              ancestors: { a: [], b: ['a'], c: ['a'], d: ['a', 'a/b', 'a/b/e', 'a/c'], e: ['a', 'a/b'] },
              pathnames: { a: ['a'], b: ['a/b'], c: ['a/c'], d: ['a/c/d', 'a/b/e/d'], e: ['a/b/e'] }
            }
          }, {
            name: 'Two child with same parent_ids and one drops one of the parent_ids',
            starting_graph: {
              parent_ids: { a: [], b: [], c: ['a', 'b'], d: ['a', 'b'] },
              ancestors: { a: [], b: [], c: ['a', 'b'], d: ['a', 'b'] },
              pathnames: { a: ['a'], b: ['b'], c: ['a/c', 'b/c'], d: ['a/d', 'b/d'] }
            },
            preservation_document_attributes_to_update: { id: :c, parent_ids: ['a'] },
            ending_graph: {
              parent_ids: { a: [], b: [], c: ['a'], d: ['a', 'b'] },
              ancestors: { a: [], b: [], c: ['a'], d: ['a', 'b'] },
              pathnames: { a: ['a'], b: ['b'], c: ['a/c'], d: ['a/d', 'b/d'] }
            }
          }, {
            name: 'Switching top-level parent_ids in a nested graph',
            starting_graph: {
              parent_ids: { a: [], b: ['a'], c: ['a', 'b'], d: ['b', 'c'], e: ['b', 'c'], f: ['e'], g: [] },
              ancestors: {
                a: [], b: ['a'], c: ['a', 'a/b'], d: ['a', 'a/b', 'a/b/c', 'a/c'], e: ['a', 'a/b', 'a/b/c', 'a/c'],
                f: ['a', 'a/b', 'a/b/e', 'a/b/c', 'a/b/c/e', 'a/c', 'a/c/e'], g: []
              },
              pathnames: {
                a: ['a'], b: ['a/b'], c: ['a/c', 'a/b/c'], d: ['a/b/d', 'a/b/c/d', 'a/c/d'], e: ['a/b/e', 'a/b/c/e', 'a/c/e'],
                f: ['a/b/e/f', 'a/b/c/e/f', 'a/c/e/f'], g: ['g']
              }
            },
            preservation_document_attributes_to_update: { id: :b, parent_ids: ['g'] },
            ending_graph: {
              parent_ids: { a: [], b: ['g'], c: ['a', 'b'], d: ['b', 'c'], e: ['b', 'c'], f: ['e'], g: [] },
              ancestors: {
                a: [], b: ['g'], c: ['a', 'g', 'g/b'], d: ['g', 'g/b', 'g/b/c', 'a', 'a/c'], e: ['g', 'g/b', 'g/b/c', 'a', 'a/c'],
                f: ['a', 'a/c', 'a/c/e', 'g', 'g/b', 'g/b/c', 'g/b/c/e', 'g/b/e'], g: []
              },
              pathnames: {
                a: ['a'], b: ['g/b'], c: ['a/c', 'g/b/c'], d: ['g/b/d', 'g/b/c/d', 'a/c/d'], e: ['g/b/e', 'g/b/c/e', 'a/c/e'],
                f: ['g/b/e/f', 'g/b/c/e/f', 'a/c/e/f'], g: ['g']
              }
            }
          }, {
            name: 'Nesting one nested set of nodes within another node',
            starting_graph: {
              parent_ids: { pnc: [], pub_gw: ['pnc'], pc: [], auth_gw: ['pc'], cc: ['pc'], priv_gw: ['cc'] },
              ancestors: { pnc: [], pub_gw: ['pnc'], pc: [], auth_gw: ['pc'], cc: ['pc'], priv_gw: ['pc/cc', 'pc'] },
              pathnames: {
                pnc: ['pnc'], pub_gw: ['pnc/pub_gw'], pc: ['pc'], auth_gw: ['pc/auth_gw'], cc: ['pc/cc'], priv_gw: ['pc/cc/priv_gw']
              }
            },
            preservation_document_attributes_to_update: { id: :pc, parent_ids: ['pnc'] },
            ending_graph: {
              parent_ids: { pnc: [], pub_gw: ['pnc'], pc: ['pnc'], auth_gw: ['pc'], cc: ['pc'], priv_gw: ['cc'] },
              ancestors: { pnc: [], pub_gw: ['pnc'], pc: ['pnc'], auth_gw: ['pnc', 'pnc/pc'], cc: ['pnc', 'pnc/pc'], priv_gw: ['pnc', 'pnc/pc', 'pnc/pc/cc'] },
              pathnames: {
                pnc: ['pnc'], pub_gw: ['pnc/pub_gw'], pc: ['pnc/pc'], auth_gw: ['pnc/pc/auth_gw'], cc: ['pnc/pc/cc'], priv_gw: ['pnc/pc/cc/priv_gw']
              }
            }
          }
        ].each_with_index do |the_scenario, index|
          context "#{the_scenario.fetch(:name)} (Scenario #{index})" do
            let(:starting_graph) { the_scenario.fetch(:starting_graph) }
            let(:preservation_document_attributes_to_update) { the_scenario.fetch(:preservation_document_attributes_to_update) }
            let(:ending_graph) { the_scenario.fetch(:ending_graph) }
            it 'will update the graph' do
              # A custom test helper method that builds the starting graph in the indexing and persistence layer.
              # This builds the "initial" data state
              build_graph(starting_graph)

              # Logic that mirrors the behavior of updating an ActiveFedora object.
              write_document_to_persistence_layers(preservation_document_attributes_to_update)

              # Run the "job" that will reindex the relationships for the given id.
              NestingIndexer.reindex_relationships(id: preservation_document_attributes_to_update.fetch(:id), extent: nil)

              # A custom spec helper that verifies the expected ending graph versus the actual graph as retrieved
              # This verifies the "ending" data state
              verify_graph_versus_storage(ending_graph)
            end
          end
        end
      end

      context "Cyclical graphs" do
        it 'will catch due to a time to live constraint' do
          starting_graph = {
            parent_ids: { a: [], b: ['a', 'd'], c: ['b'], d: ['c'] },
            ancestors: { a: [], b: ['a', 'c', 'd', 'b'], c: ['a', 'b'], d: ['a', 'b', 'c'] },
            pathnames: { a: [], b: ['a/b', 'b/d', 'b/d/c'], c: ['a/c', 'b/c'], d: ['a/d', 'b/d'] }
          }
          build_graph(starting_graph)

          expect { NestingIndexer.reindex_relationships(id: :a, extent: nil) }.to raise_error(Exceptions::CycleDetectionError)
        end

        it 'catches a simple cyclic graph (start with A ={ B and add B ={ A relationship)' do
          ancestor_error = Samvera::NestingIndexer::Exceptions::DocumentIsItsOwnAncestorError
          starting_graph = {
            parent_ids: { a: [], b: ['a'] }
          }
          build_graph(starting_graph)

          NestingIndexer.reindex_all!

          ending_graph = {
            parent_ids: { a: [], b: ['a'] },
            ancestors: { a: [], b: ['a'] },
            pathnames: { a: ['a'], b: ['a/b'] }
          }
          verify_graph_versus_storage(ending_graph)

          # We are writing (and succeeding at writing) a cyclic relationship
          NestingIndexer.adapter.write_document_attributes_to_preservation_layer(id: :a, parent_ids: ['b'])
          expect { NestingIndexer.reindex_relationships(id: :a, extent: nil) }.to raise_error(ancestor_error)

          # We should have the same index that we started with.
          verify_graph_versus_storage(ending_graph)
        end

        it 'catches a simple cyclic graph (start with A ={ B ={ C and add C ={ B relationship)' do
          ancestor_error = Samvera::NestingIndexer::Exceptions::DocumentIsItsOwnAncestorError
          starting_graph = {
            parent_ids: { a: [], b: ['a'], c: ['b'] }
          }
          build_graph(starting_graph)

          NestingIndexer.reindex_all!

          ending_graph = {
            parent_ids: { a: [], b: ['a'], c: ['b'] },
            ancestors: { a: [], b: ['a'], c: ['a', 'a/b'] },
            pathnames: { a: ['a'], b: ['a/b'], c: ['a/b/c'] }
          }
          verify_graph_versus_storage(ending_graph)

          # We are writing (and succeeding at writing) a cyclic relationship
          NestingIndexer.adapter.write_document_attributes_to_preservation_layer(id: :b, parent_ids: ['a', 'c'])
          expect { NestingIndexer.reindex_relationships(id: :b, extent: nil) }.to raise_error(ancestor_error)

          # We should have the same index that we started with.
          verify_graph_versus_storage(ending_graph)
        end

        it 'catches a simple cyclic graph (start with A ={ B ={ C and add C ={ B relationship)' do
          starting_graph = {
            parent_ids: { a: [], b: ['a'], c: ['b'], d: ['c'] }
          }
          build_graph(starting_graph)
          # If we give enough time to live this will index
          expect { NestingIndexer.reindex_relationships(id: :a, maximum_nesting_depth: 5, extent: nil) }.not_to raise_error

          # If we don't give enough time to live this will fail in indexing
          expect { NestingIndexer.reindex_relationships(id: :a, maximum_nesting_depth: 2, extent: nil) }.to(
            raise_error(Samvera::NestingIndexer::Exceptions::CycleDetectionError)
          )
        end
      end

      context "Bootstrapping a graph" do
        it 'indexes with a non-trivial graph' do
          starting_graph = {
            parent_ids: { a: [], b: ['a'], c: ['a', 'b'], d: ['b', 'c'], e: ['b', 'c'], f: ['e'], g: [] }
          }
          build_graph(starting_graph)
          NestingIndexer.reindex_all!
          ending_graph = {
            parent_ids: { a: [], b: ['a'], c: ['a', 'b'], d: ['b', 'c'], e: ['b', 'c'], f: ['e'], g: [] },
            ancestors: {
              a: [], b: ['a'], c: ['a', 'a/b'], d: ['a', 'a/b', 'a/b/c', 'a/c'], e: ['a', 'a/b', 'a/b/c', 'a/c'],
              f: ['a', 'a/b', 'a/b/e', 'a/b/c', 'a/b/c/e', 'a/c', 'a/c/e'], g: []
            },
            pathnames: {
              a: ['a'], b: ['a/b'], c: ['a/c', 'a/b/c'], d: ['a/b/d', 'a/b/c/d', 'a/c/d'], e: ['a/b/e', 'a/b/c/e', 'a/c/e'],
              f: ['a/b/e/f', 'a/b/c/e/f', 'a/c/e/f'], g: ['g']
            }
          }
          verify_graph_versus_storage(ending_graph)
        end

        it 'verifying the structure of ancestors' do
          starting_graph = {
            parent_ids: { a: [], b: ['a'], c: ['b', 'e'], d: [], e: ['d'] }
          }
          build_graph(starting_graph)

          NestingIndexer.reindex_all!

          ending_graph = {
            parent_ids: { a: [], b: ['a'], c: ['b', 'e'], d: [], e: ['d'] },
            ancestors: { a: [], b: ['a'], c: ['a', 'a/b', 'd', 'd/e'], d: [], e: ['d'] },
            pathnames: { a: ['a'], b: ['a/b'], c: ['a/b/c', 'd/e/c'], d: ['d'], e: ['d/e'] }
          }
          verify_graph_versus_storage(ending_graph)
        end

        it 'indexes a non-cyclic graph' do
          starting_graph = {
            parent_ids: { a: [], b: ['a'], c: ['a', 'b'], d: ['b'], e: ['c', 'd'], f: [] }
          }
          build_graph(starting_graph)

          NestingIndexer.reindex_all!

          ending_graph = {
            parent_ids: { a: [], b: ['a'], c: ['a', 'b'], d: ['b'], e: ['c', 'd'], f: [] },
            ancestors: { a: [], b: ['a'], c: ['a/b', 'a'], d: ['a', 'a/b'], e: ['a', 'a/b', 'a/b/c', 'a/b/d', 'a/c'], f: [] },
            pathnames: { a: ['a'], b: ['a/b'], c: ['a/c', 'a/b/c'], d: ['a/b/d'], e: ['a/c/e', 'a/b/c/e', 'a/b/d/e'], f: ['f'] }
          }
          verify_graph_versus_storage(ending_graph)
        end

        it 'indexes a non-cyclic graph not declared in parent order' do
          starting_graph = {
            parent_ids: { a: ['b'], b: ['c'], c: [] }
          }
          build_graph(starting_graph)

          NestingIndexer.reindex_all!

          ending_graph = {
            parent_ids: { a: ['b'], b: ['c'], c: [] },
            ancestors: { a: ['c/b', 'c'], b: ['c'], c: [] },
            pathnames: { a: ['c/b/a'], b: ['c/b'], c: ['c'] }
          }
          verify_graph_versus_storage(ending_graph)
        end

        it 'catches a cyclic graph definition' do
          starting_graph = {
            parent_ids: { a: [], b: ['a', 'd'], c: ['b'], d: ['c'] }
          }
          build_graph(starting_graph)
          expect { NestingIndexer.reindex_all! }.to raise_error(Exceptions::ReindexingError)
        end
      end
    end
  end
end
