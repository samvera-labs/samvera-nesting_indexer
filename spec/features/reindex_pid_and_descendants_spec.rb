require 'spec_helper'
require 'curate/indexer'
require 'curate/indexer/exceptions'
require 'curate/indexer/preservation'
require 'curate/indexer/index'

# :nodoc:
module Curate
  module Indexer
    RSpec.describe 'Reindex pid and descendants' do
      before do
        Preservation::Storage.clear_cache!
        Index::Storage.clear_cache!
      end

      def build_graph(graph)
        # Create the starting_graph
        graph.fetch(:parent_pids).keys.each do |pid|
          build_preservation_document(pid, graph)
          build_index_document(pid, graph)
        end
      end

      def build_preservation_document(pid, graph)
        parent_pids = graph.fetch(:parent_pids).fetch(pid)
        Preservation::Document.new(pid: pid, parent_pids: parent_pids).write
      end

      def build_index_document(pid, graph)
        return unless graph.key?(:ancestors)
        return unless graph.key?(:pathnames)
        Index::Document.new(
          pid: pid,
          parent_pids: graph.fetch(:parent_pids).fetch(pid),
          ancestors: graph.fetch(:ancestors).fetch(pid),
          pathnames: graph.fetch(:pathnames).fetch(pid)
        ).write
      end

      context "non-Cycle graphs" do
        [
          {
            name: 'A semi-complicated graph with diamonds and triangle relationships',
            starting_graph: {
              parent_pids: { a: [], b: ['a'], c: ['a', 'b'], d: ['c', 'e'], e: ['b'] },
              ancestors: { a: [], b: ['a'], c: ['a/b', 'a'], d: ['a', 'a/b', 'a/b/c', 'a/b/e', 'a/c'], e: ['a', 'a/b'] },
              pathnames: { a: ['a'], b: ['a/b'], c: ['a/c', 'a/b/c'], d: ['a/c/d', 'a/b/c/d', 'a/b/e/d'], e: ['a/b/e'] }
            },
            preservation_document_attributes: { pid: :c, parent_pids: ['a'] },
            ending_graph: {
              parent_pids: { a: [], b: ['a'], c: ['a'], d: ['c', 'e'], e: ['b'] },
              ancestors: { a: [], b: ['a'], c: ['a'], d: ['a', 'a/b', 'a/b/e', 'a/c'], e: ['a', 'a/b'] },
              pathnames: { a: ['a'], b: ['a/b'], c: ['a/c'], d: ['a/c/d', 'a/b/e/d'], e: ['a/b/e'] }
            }
          }, {
            name: 'Two child with same parent_pids and one drops one of the parent_pids',
            starting_graph: {
              parent_pids: { a: [], b: [], c: ['a', 'b'], d: ['a', 'b'] },
              ancestors: { a: [], b: [], c: ['a', 'b'], d: ['a', 'b'] },
              pathnames: { a: ['a'], b: ['b'], c: ['a/c', 'b/c'], d: ['a/d', 'b/d'] }
            },
            preservation_document_attributes: { pid: :c, parent_pids: ['a'] },
            ending_graph: {
              parent_pids: { a: [], b: [], c: ['a'], d: ['a', 'b'] },
              ancestors: { a: [], b: [], c: ['a'], d: ['a', 'b'] },
              pathnames: { a: ['a'], b: ['b'], c: ['a/c'], d: ['a/d', 'b/d'] }
            }
          }, {
            name: 'Switching top-level parent_pids in a nested graph',
            starting_graph: {
              parent_pids: { a: [], b: ['a'], c: ['a', 'b'], d: ['b', 'c'], e: ['b', 'c'], f: ['e'], g: [] },
              ancestors: {
                a: [], b: ['a'], c: ['a', 'a/b'], d: ['a', 'a/b', 'a/b/c', 'a/c'], e: ['a', 'a/b', 'a/b/c', 'a/c'],
                f: ['a', 'a/b', 'a/b/e', 'a/b/c', 'a/b/c/e', 'a/c', 'a/c/e'], g: []
              },
              pathnames: {
                a: ['a'], b: ['a/b'], c: ['a/c', 'a/b/c'], d: ['a/b/d', 'a/b/c/d', 'a/c/d'], e: ['a/b/e', 'a/b/c/e', 'a/c/e'],
                f: ['a/b/e/f', 'a/b/c/e/f', 'a/c/e/f'], g: ['g']
              }
            },
            preservation_document_attributes: { pid: :b, parent_pids: ['g'] },
            ending_graph: {
              parent_pids: { a: [], b: ['g'], c: ['a', 'b'], d: ['b', 'c'], e: ['b', 'c'], f: ['e'], g: [] },
              ancestors: {
                a: [], b: ['g'], c: ['a', 'g', 'g/b'], d: ['g', 'g/b', 'g/b/c', 'a', 'a/c'], e: ['g', 'g/b', 'g/b/c', 'a', 'a/c'],
                f: ['a', 'a/c', 'a/c/e', 'g', 'g/b', 'g/b/c', 'g/b/c/e', 'g/b/e'], g: []
              },
              pathnames: {
                a: ['a'], b: ['g/b'], c: ['a/c', 'g/b/c'], d: ['g/b/d', 'g/b/c/d', 'a/c/d'], e: ['g/b/e', 'g/b/c/e', 'a/c/e'],
                f: ['g/b/e/f', 'g/b/c/e/f', 'a/c/e/f'], g: ['g']
              }
            }
          }
        ].each_with_index do |the_scenario, index|
          context "#{the_scenario.fetch(:name)} (Scenario #{index})" do
            let(:starting_graph) { the_scenario.fetch(:starting_graph) }
            let(:preservation_document_attributes) { the_scenario.fetch(:preservation_document_attributes) }
            let(:ending_graph) { the_scenario.fetch(:ending_graph) }
            it 'will update the graph' do
              build_graph(starting_graph)

              # Perform the update to the Fedora document
              Preservation::Document.new(preservation_document_attributes).write
              Indexer.reindex_relationships(preservation_document_attributes.fetch(:pid))

              # Verify the expected behavior
              verify_graph_versus_storage(ending_graph)
            end
          end
        end
      end

      def verify_graph_versus_storage(ending_graph)
        ending_graph.fetch(:parent_pids).keys.each do |pid|
          document = Index::Document.new(
            pid: pid,
            parent_pids: ending_graph.fetch(:parent_pids).fetch(pid),
            ancestors: ending_graph.fetch(:ancestors).fetch(pid),
            pathnames: ending_graph.fetch(:pathnames).fetch(pid)
          )
          expect(Index::Storage.find(pid)).to eq(document)
        end
      end

      context "Cyclical graphs" do
        it 'will catch due to a time to live constraint' do
          starting_graph = {
            parent_pids: { a: [], b: ['a', 'd'], c: ['b'], d: ['c'] },
            ancestors: { a: [], b: ['a', 'c', 'd', 'b'], c: ['a', 'b'], d: ['a', 'b', 'c'] },
            pathnames: { a: [], b: ['a/b', 'b/d', 'b/d/c'], c: ['a/c', 'b/c'], d: ['a/d', 'b/d'] }
          }
          build_graph(starting_graph)

          expect { Indexer.reindex_relationships(:a) }.to raise_error(Exceptions::CycleDetectionError)
        end
      end

      context "Bootstrapping a graph" do
        it 'indexes a non-cyclical graph' do
          starting_graph = {
            parent_pids: { a: [], b: ['a'], c: ['a', 'b'], d: ['b'], e: ['c', 'd'], f: [] }
          }
          build_graph(starting_graph)

          Indexer.reindex_all!

          ending_graph = {
            parent_pids: { a: [], b: ['a'], c: ['a', 'b'], d: ['b'], e: ['c', 'd'], f: [] },
            ancestors: { a: [], b: ['a'], c: ['a/b', 'a'], d: ['a', 'a/b'], e: ['a', 'a/b', 'a/b/c', 'a/b/d', 'a/c'], f: [] },
            pathnames: { a: ['a'], b: ['a/b'], c: ['a/c', 'a/b/c'], d: ['a/b/d'], e: ['a/c/e', 'a/b/c/e', 'a/b/d/e'], f: ['f'] }
          }
          verify_graph_versus_storage(ending_graph)
        end

        it 'indexes a non-cyclical graph not declared in parent order' do
          starting_graph = {
            parent_pids: { a: ['b'], b: ['c'], c: [] }
          }
          build_graph(starting_graph)

          Indexer.reindex_all!

          ending_graph = {
            parent_pids: { a: ['b'], b: ['c'], c: [] },
            ancestors: { a: ['c/b', 'c'], b: ['c'], c: [] },
            pathnames: { a: ['c/b/a'], b: ['c/b'], c: ['c'] }
          }
          verify_graph_versus_storage(ending_graph)
        end

        it 'catches a cyclical graph definition' do
          starting_graph = {
            parent_pids: { a: [], b: ['a', 'd'], c: ['b'], d: ['c'] }
          }
          build_graph(starting_graph)
          expect { Indexer.reindex_all! }.to raise_error(Exceptions::CycleDetectionError)
        end
      end
    end
  end
end
