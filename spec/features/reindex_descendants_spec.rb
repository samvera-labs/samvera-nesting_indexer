require 'spec_helper'
require 'curate/indexer'
require 'curate/indexer/exceptions'
require 'set'
require 'dry-equalizer'
require 'dry-initializer'
require 'forwardable'

# :nodoc:
module Curate
  module Indexer
    # :nodoc:
    module StorageModule
      def write(doc)
        cache[doc.pid] = doc
      end

      def find(pid)
        cache.fetch(pid.to_s)
      end

      def clear_cache!
        @cache = {}
      end

      def cache
        @cache ||= {}
      end
      private :cache
    end

    # :nodoc:
    module Preservation
      class Document
        extend Dry::Initializer::Mixin
        option :pid, type: Types::Coercible::String
        option :parents, type: Types::Coercible::Array

        def write
          Storage.write(self)
        end
      end
      # :nodoc:
      module Storage
        extend StorageModule
      end
    end
    # :nodoc:
    module Index
      # :nodoc:
      class Document
        include Dry::Equalizer(:pid, :sorted_parents, :sorted_pathnames, :sorted_ancestors)
        extend Dry::Initializer::Mixin
        option :pid, type: Types::Coercible::String
        option :parents, type: Types::Coercible::Array
        option :pathnames, type: Types::Coercible::Array
        option :ancestors, type: Types::Coercible::Array

        def write
          Storage.write(self)
        end

        def sorted_parents
          parents.sort
        end

        def sorted_pathnames
          pathnames.sort
        end

        def sorted_ancestors
          ancestors.sort
        end
      end

      # :nodoc:
      module Storage
        extend StorageModule
        def self.find_children_of_pid(pid)
          cache.values.select { |document| document.parents.include?(pid) }
        end
      end
    end

    # :nodoc:
    class Reindexer
      extend Forwardable
      ProcessingDocument = Struct.new(:pid, :time_to_live)

      # This assumes a rather deep graph
      DEFAULT_TIME_TO_LIVE = 15
      def self.reindex_descendants(pid, time_to_live = DEFAULT_TIME_TO_LIVE)
        new(pid: pid, time_to_live: time_to_live).call
      end
      extend Dry::Initializer::Mixin
      option :pid, type: Types::Coercible::String
      option :time_to_live, type: Types::Coercible::Int
      option :queue, default: proc { [] }

      def call
        with_each_indexed_child_of(pid) { |child| enqueue(child.pid, time_to_live) }
        index_document = dequeue
        while index_document
          process_a_document(index_document)
          with_each_indexed_child_of(index_document.pid) { |child| enqueue(child.pid, index_document.time_to_live - 1) }
          index_document = dequeue
        end
        self
      end

      private

      def_delegator :queue, :shift, :dequeue

      def enqueue(pid, time_to_live)
        queue.push(ProcessingDocument.new(pid, time_to_live))
      end

      def process_a_document(index_document)
        raise Exceptions::CycleDetectionError, pid if index_document.time_to_live <= 0
        preservation_document = Preservation::Storage.find(index_document.pid)
        Index::Document.new(parents_and_path_and_ancestors_for(preservation_document)).write
      end

      def parents_and_path_and_ancestors_for(preservation_document)
        ParentAndPathAndAncestorsBuilder.new(preservation_document).to_hash
      end

      class ParentAndPathAndAncestorsBuilder
        def initialize(preservation_document)
          @preservation_document = preservation_document
          @parents = Set.new
          @pathnames = Set.new
          @ancestors = Set.new
          compile!
        end

        def to_hash
          { pid: @preservation_document.pid, parents: @parents.to_a, pathnames: @pathnames.to_a, ancestors: @ancestors.to_a }
        end

        private

        def compile!
          @preservation_document.parents.each do |parent_pid|
            parent_index_document = Index::Storage.find(parent_pid)
            compile_one!(parent_index_document)
          end
        end

        def compile_one!(parent_index_document)
          @parents << parent_index_document.pid
          parent_index_document.pathnames.each do |pathname|
            @pathnames << File.join(pathname, @preservation_document.pid)
            slugs = pathname.split("/")
            slugs.each_index { |i| @ancestors << slugs[0..i].join('/') }
          end
          @ancestors += parent_index_document.ancestors
        end
      end
      private_constant :ParentAndPathAndAncestorsBuilder

      def with_each_indexed_child_of(pid)
        Index::Storage.find_children_of_pid(pid).each { |child| yield(child) }
      end

      attr_writer :document
    end
    RSpec.describe 'Reindex descendants' do
      before do
        Preservation::Storage.clear_cache!
        Index::Storage.clear_cache!
      end

      def build_graph(graph)
        # Create the starting_graph
        graph.fetch(:parents).keys.each do |pid|
          parents = graph.fetch(:parents).fetch(pid)
          Preservation::Document.new(pid: pid, parents: parents).write
          Index::Document.new(
            pid: pid,
            parents: parents,
            ancestors: graph.fetch(:ancestors).fetch(pid),
            pathnames: graph.fetch(:pathnames).fetch(pid)
          ).write
        end
      end

      context "non-Cycle graphs" do
        [
          {
            name: 'A semi-complicated graph with diamonds and triangle relationships',
            starting_graph: {
              parents: { a: [], b: ['a'], c: ['a', 'b'], d: ['c', 'e'], e: ['b'] },
              ancestors: { a: [], b: ['a'], c: ['a/b', 'a'], d: ['a', 'a/b', 'a/b/c', 'a/b/e', 'a/c'], e: ['a', 'a/b'] },
              pathnames: { a: ['a'], b: ['a/b'], c: ['a/c', 'a/b/c'], d: ['a/c/d', 'a/b/c/d', 'a/b/e/d'], e: ['a/b/e'] }
            },
            updated_attributes: { pid: :c, parents: ['a'], pathnames: ['a/c'], ancestors: ['a'] },
            ending_graph: {
              parents: { a: [], b: ['a'], c: ['a'], d: ['c', 'e'], e: ['b'] },
              ancestors: { a: [], b: ['a'], c: ['a'], d: ['a', 'a/b', 'a/b/e', 'a/c'], e: ['a', 'a/b'] },
              pathnames: { a: ['a'], b: ['a/b'], c: ['a/c'], d: ['a/c/d', 'a/b/e/d'], e: ['a/b/e'] }
            }
          }, {
            name: 'Two child with same parents and one drops one of the parents',
            starting_graph: {
              parents: { a: [], b: [], c: ['a', 'b'], d: ['a', 'b'] },
              ancestors: { a: [], b: [], c: ['a', 'b'], d: ['a', 'b'] },
              pathnames: { a: ['a'], b: ['b'], c: ['a/c', 'b/c'], d: ['a/d', 'b/d'] }
            },
            updated_attributes: { pid: :c, parents: ['a'], pathnames: ['a/c'], ancestors: ['a'] },
            ending_graph: {
              parents: { a: [], b: [], c: ['a'], d: ['a', 'b'] },
              ancestors: { a: [], b: [], c: ['a'], d: ['a', 'b'] },
              pathnames: { a: ['a'], b: ['b'], c: ['a/c'], d: ['a/d', 'b/d'] }
            }
          }, {
            name: 'Switching top-level parents in a nested graph',
            starting_graph: {
              parents: { a: [], b: ['a'], c: ['a', 'b'], d: ['b', 'c'], e: ['b', 'c'], f: ['e'], g: [] },
              ancestors: {
                a: [], b: ['a'], c: ['a', 'a/b'], d: ['a', 'a/b', 'a/b/c', 'a/c'], e: ['a', 'a/b', 'a/b/c', 'a/c'],
                f: ['a', 'a/b', 'a/b/e', 'a/b/c', 'a/b/c/e', 'a/c', 'a/c/e'], g: []
              },
              pathnames: {
                a: ['a'], b: ['a/b'], c: ['a/c', 'a/b/c'], d: ['a/b/d', 'a/b/c/d', 'a/c/d'], e: ['a/b/e', 'a/b/c/e', 'a/c/e'],
                f: ['a/b/e/f', 'a/b/c/e/f', 'a/c/e/f'], g: ['g']
              }
            },
            updated_attributes: { pid: :b, parents: ['g'], pathnames: ['g/b'], ancestors: ['g'] },
            ending_graph: {
              parents: { a: [], b: ['g'], c: ['a', 'b'], d: ['b', 'c'], e: ['b', 'c'], f: ['e'], g: [] },
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
            let(:updated_attributes) { the_scenario.fetch(:updated_attributes) }
            let(:ending_graph) { the_scenario.fetch(:ending_graph) }
            it 'will update the graph' do
              build_graph(starting_graph)

              # Perform the update to the Fedora document
              Preservation::Document.new(pid: updated_attributes.fetch(:pid), parents: updated_attributes.fetch(:parents)).write
              # Perform the ActiveFedora "update_index"
              Index::Document.new(updated_attributes).write

              Reindexer.reindex_descendants(updated_attributes.fetch(:pid))

              # Verify the expected behavior
              ending_graph.fetch(:parents).keys.each do |pid|
                document = Index::Document.new(
                  pid: pid,
                  parents: ending_graph.fetch(:parents).fetch(pid),
                  ancestors: ending_graph.fetch(:ancestors).fetch(pid),
                  pathnames: ending_graph.fetch(:pathnames).fetch(pid)
                )
                expect(Index::Storage.find(pid)).to eq(document)
              end
            end
          end
        end
      end

      context "Cyclical graphs" do
        it 'will catch due to a time to live constraint' do
          starting_graph = {
            parents: { a: [], b: ['a', 'd'], c: ['b'], d: ['c'] },
            ancestors: { a: [], b: ['a', 'c', 'd', 'b'], c: ['a', 'b'], d: ['a', 'b', 'c'] },
            pathnames: { a: [], b: ['a/b', 'b/d', 'b/d/c'], c: ['a/c', 'b/c'], d: ['a/d', 'b/d'] }
          }
          build_graph(starting_graph)

          expect { Reindexer.reindex_descendants(:a) }.to raise_error(Exceptions::CycleDetectionError)
        end
      end
    end
  end
end
