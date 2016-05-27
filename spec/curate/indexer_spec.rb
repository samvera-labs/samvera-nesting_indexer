require 'spec_helper'
require 'rspec/its'

require 'set'
require 'dry-equalizer'
require 'forwardable'

module Curate
  module Indexer
    class RuntimeError < RuntimeError
    end
    class ReindexingReachedMaxLevelError < RuntimeError
      attr_accessor :requested_pid, :visited_pids, :max_level
      def initialize(requested_pid:, visited_pids:, max_level:)
        self.requested_pid = requested_pid
        self.visited_pids = visited_pids
        self.max_level = max_level
        super("ERROR: Reindexing reached level #{max_level} on PID:#{requested_pid}. Possible graph cycle detected.")
      end
    end
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
    private_constant :Queue

    module Cache
      def find(key, &block)
        cache.fetch(key, &block)
      end
      def cache
        @cache ||= {}
      end
      def add_to_cache(key, value)
        cache[key] ||= value
      end
      def clear_cache!
        @cache = {}
      end
    end
    private_constant :Cache

    module Index
      def self.new_rebuilder(requested_for:)
        Rebuilder.new(requested_for: requested_for)
      end
      class Rebuilder
        def initialize(requested_for:)
          self.requested_for = requested_for
          self.cache = {}
        end
        def associate(document:, is_member_of_document:)
          document_writer = find_or_build_writer_for(document: document)
          is_member_of_document_writer = find_or_build_writer_for(document: is_member_of_document)
          [
            :is_transitive_member_of,
            :is_member_of,
            :has_collection_members,
            :has_transitive_collection_members
          ].each do |method_name|
            document_writer.public_send("add_#{method_name}", *document.public_send(method_name))
            is_member_of_document_writer.public_send("add_#{method_name}", *is_member_of_document.public_send(method_name))
          end
          document_writer.add_is_member_of(is_member_of_document_writer.pid)
          document_writer.add_is_transitive_member_of(is_member_of_document_writer.pid, *is_member_of_document_writer.is_transitive_member_of)
          is_member_of_document_writer.add_has_collection_members(document_writer.pid)
          is_member_of_document_writer.add_has_transitive_collection_members(document_writer.pid, *document_writer.has_transitive_collection_members)
        end
        def rebuild_and_return_requested_for
          returning_value = nil
          cache.each_value do |writer_document|
            writer_document.write! # Persist to the cache
            returning_value = writer_document if requested_for.pid == writer_document.pid
          end
          returning_value
        end

        def visited_pids
          cache.keys
        end

        attr_reader :requested_for
        private
        attr_writer :requested_for
        attr_accessor :cache

        def find_or_build_writer_for(document:)
          cache[document.pid] ||= Document.new(pid: document.pid)
        end
      end

      class Document
        include Dry::Equalizer(:pid)
        attr_reader :pid
        def initialize(pid:)
          self.pid = pid
          instance_exec { yield(self) } if block_given?
          # Ensuring that transitive relations always contain direct members
          self.is_transitive_member_of = is_transitive_member_of + is_member_of
          self.has_transitive_collection_members = has_transitive_collection_members + has_collection_members
        end

        def inspect
          vars = instance_variables.map { |ivar| "#{ivar}=#{instance_variable_get(ivar).inspect}" }.join(' ')
          %(#<Indexer::Index::Document #{vars}>)
        end

        [
          :is_transitive_member_of,
          :is_member_of,
          :has_collection_members,
          :has_transitive_collection_members
        ].each do |method_name|
          define_method(method_name) do
            (instance_variable_get("@#{method_name}") || []).to_a
          end

          define_method("#{method_name}=") do |values|
            send("add_#{method_name}", values)
          end

          define_method("add_#{method_name}") do |*pids|
            if instance_variable_get("@#{method_name}")
              instance_variable_set("@#{method_name}", (instance_variable_get("@#{method_name}") + Array(pids).flatten))
            else
              instance_variable_set("@#{method_name}", Set.new(Array(pids).flatten))
            end
          end
        end

        def write!
          Index::Query.cache[pid] = self
        end
        private
        attr_writer :pid
      end

      module Query
        extend Cache
        def self.find(pid)
          cache.fetch(pid)
        rescue KeyError
          cache[pid] = Document.new(pid: pid)
        end
      end
    end

    # Responsible for coordinating all of the building process of the new index
    # data.
    module Processing
      extend Cache
      def self.find_or_create_processing_document_for(pid:, level:, **keywords)
        cache.fetch(pid).fetch(level)
      rescue KeyError
        cache[pid] ||= {}
        cache[pid][level] = Builder.new(pid: pid, level: level, **keywords).build
      end

      class Builder
        def initialize(pid:, level:, persistence_finder: default_persistence_finder, index_finder: default_index_finder)
          self.pid = pid
          self.level = level
          self.persistence_finder = persistence_finder
          self.index_finder = index_finder
        end

        def build
          persisted_document = persistence_finder.call(pid: pid)
          index_document = index_finder.call(pid: pid)
          build_from(persisted_document: persisted_document, index_document: index_document)
        end

        attr_reader :pid, :level, :persistence_finder, :index_finder
        private
        attr_writer :pid, :level, :persistence_finder, :index_finder

        def build_from(persisted_document:, index_document:)
          QueryDocument.new(pid: pid, level: level) do |query_document|
            query_document.is_transitive_member_of = index_document.is_transitive_member_of
            query_document.is_member_of = persisted_document.is_member_of
            query_document.has_transitive_collection_members = index_document.has_transitive_collection_members
            query_document.has_collection_members = index_document.has_collection_members
          end
        end

        def default_persistence_finder
          ->(pid:) { Persistence.find(pid) }
        end

        def default_index_finder
          ->(pid:) { Index::Query.find(pid) }
        end
      end
      private_constant :Builder

      class QueryDocument
        include Dry::Equalizer(:pid, :level)
        attr_reader :pid, :level
        def initialize(pid:, level:)
          self.pid = pid
          self.level = level
          instance_exec { yield(self) } if block_given?
          # Ensuring that transitive relations always contain direct members
          self.is_transitive_member_of = is_transitive_member_of + is_member_of
          self.has_transitive_collection_members = has_transitive_collection_members + has_collection_members
        end

        [
          :is_transitive_member_of,
          :is_member_of,
          :has_collection_members,
          :has_transitive_collection_members
        ].each do |method_name|
          define_method(method_name) do
            (instance_variable_get("@#{method_name}") || []).to_a
          end

          define_method("#{method_name}=") do |values|
            instance_variable_set("@#{method_name}", Set.new(Array(values)))
          end
        end
        private
        attr_writer :pid, :level
      end
      private_constant :QueryDocument
    end

    # Responsible for being a layer between Fedora and the heavy lifting of the
    # reindexing processor. It has aspects that will need to change.
    module Persistence
      extend Cache
      def self.find_and_cache_document(pid:)
        find(pid: pid).tap do |document|
          cache[pid] = document
        end
      end

      # This is a disposable intermediary between Fedora and the processing system for reindexing.
      class Document
        include Dry::Equalizer(:pid)
        attr_reader :pid, :is_member_of
        def initialize(pid:, is_member_of: [])
          # A concession that when I make something it should be persisted.
          Persistence.add_to_cache(pid, self)
          self.pid = pid
          self.is_member_of = is_member_of
        end
        def type
          self.class.to_s
        end
        alias is_member_of is_member_of
        private
        attr_writer :pid
        def is_member_of=(input)
          # I'd prefer Array.wrap, but I'm assuming we won't have a DateTime object
          @is_member_of = Array(input).compact
        end
      end
      private_constant :Document

      class Collection < Document
      end

      class Work < Document
      end
    end

    def self.reindex(pid:, max_level: 20)
      document_to_reindex = Processing.find_or_create_processing_document_for(pid: pid, level: 0)
      rebuilder = Index.new_rebuilder(requested_for: document_to_reindex)
      queue = Queue.new
      queue.enqueue(document_to_reindex)
      while document = queue.dequeue
        document.is_member_of.each do |is_member_of_pid|
          next_level = document.level + 1
          if next_level >= max_level
            raise ReindexingReachedMaxLevelError, requested_pid: pid, visited_pids: rebuilder.visited_pids, max_level: max_level
          end
          is_member_of_document = Processing.find_or_create_processing_document_for(pid: is_member_of_pid, level: next_level)
          rebuilder.associate(document: document, is_member_of_document: is_member_of_document)
          queue.enqueue(is_member_of_document)
        end
      end
      rebuilder.rebuild_and_return_requested_for
    end
  end
end

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
        context 'and the existing index is not empty' do
          before do
            %w(1 3 4 5 6).each do |pid|
              Indexer.reindex(pid: pid)
            end
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
