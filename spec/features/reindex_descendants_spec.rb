require 'spec_helper'
require 'set'
require 'dry-equalizer'
require 'dry-initializer'
require 'dry-types'

# :nodoc:
module Curate
  # :nodoc:
  class Queue
    def initialize
      @queue = []
    end

    def enqueue(object)
      @queue << object
    end

    def dequeue
      @queue.shift
    end
  end
  # :nodoc:
  module Types
    include Dry::Types.module
  end

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
      def self.find_pathnames_for(pids)
        pids.map { |pid| find(pid).pathnames }.flatten.uniq
      end

      def self.find_children_of_pid(pid)
        cache.values.select { |document| document.parents.include?(pid) }
      end
    end
  end

  # :nodoc:
  class Reindexer
    DEFAULT_TIME_TO_LIVE = 7
    def self.reindex_descendants(pid, time_to_live = DEFAULT_TIME_TO_LIVE)
      new(pid: pid, time_to_live: time_to_live).call
    end
    extend Dry::Initializer::Mixin
    option :pid, type: Types::Coercible::String
    option :time_to_live, type: Types::Coercible::Int
    option :queue, default: proc { Queue.new }

    def call
      with_each_indexed_child_of(pid) { |child| queue.enqueue(child) }
      while index_document = queue.dequeue
        preservation_document = Preservation::Storage.find(index_document.pid)
        Index::Document.new(
          parents_and_path_and_ancestors_for(preservation_document)
        ).tap do |document|
          Index::Storage.write(document)
        end
        with_each_indexed_child_of(index_document.pid) { |child| queue.enqueue(child) }
      end
      self
    end

    private

    def parents_and_path_and_ancestors_for(preservation_document)
      parents = Set.new
      pathnames = Set.new
      ancestors = Set.new
      preservation_document.parents.each do |parent_pid|
        parent_index_document = Index::Storage.find(parent_pid)
        parents << parent_pid
        parent_index_document.pathnames.each do |pathname|
          pathnames << File.join(pathname, preservation_document.pid)
          slugs = pathname.split("/")
          slugs.each_index do |i|
            ancestors << slugs[0..i].join('/')
          end
        end
        ancestors += parent_index_document.ancestors
      end
      { pid: preservation_document.pid, parents: parents.to_a, pathnames: pathnames.to_a, ancestors: ancestors.to_a }
    end

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
      graph.fetch(:parents).keys.each do |node_name|
        parents = graph.fetch(:parents).fetch(node_name)
        Preservation::Document.new(pid: node_name, parents: parents).tap do |doc|
          Preservation::Storage.write(doc)
        end
        Index::Document.new(
          pid: node_name,
          parents: parents,
          ancestors: graph.fetch(:ancestors).fetch(node_name),
          pathnames: graph.fetch(:pathnames).fetch(node_name)
        ).tap do |doc|
          Index::Storage.write(doc)
        end
      end
    end

    context "non-Cycle graphs" do
      [
        {
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
          starting_graph: {
            parents: { a: [], b: [], c: ['a', 'b'], d: ['a', 'b'] },
            ancestors: { a: [], b: [], c: ['a', 'b'], d: ['a', 'b'] },
            pathnames: { a: [], b: [], c: ['a/c', 'b/c'], d: ['a/d', 'b/d'] },
          },
          updated_attributes: { pid: :c, parents: ['a'], pathnames: ['a/c'], ancestors: ['a'] },
          ending_graph: {
            parents: { a: [], b: [], c: ['a'], d: ['a', 'b'] },
            ancestors: { a: [], b: [], c: ['a'], d: ['a', 'b'] },
            pathnames: { a: [], b: [], c: ['a/c'], d: ['a/d', 'b/d'] }
          }
        }
      ].each_with_index do |the_scenario, index|
        context "Scenario #{index}" do
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
  end
end
