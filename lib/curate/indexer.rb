require "curate/indexer/version"
require 'curate/indexer/relationship_reindexer'
require 'curate/indexer/repository_reindexer'

module Curate
  # Responsible for performign the indexing of an object and its related child objects.
  module Indexer
    # This assumes a rather deep graph
    DEFAULT_TIME_TO_LIVE = 15
    # @api public
    # Responsible for reindexing the associated document for the given :pid and the descendants of that :pid.
    # In a perfect world we could reindex the pid as well; But that is for another test.
    #
    # @param pid [String] - The permanent identifier of the object that will be reindexed along with its children.
    # @param time_to_live [Integer] - there to guard against cyclical graphs
    # @return [Boolean] - It was successful
    # @raise Curate::Exceptions::CycleDetectionError - A potential cycle was detected
    def self.reindex_relationships(pid, time_to_live = DEFAULT_TIME_TO_LIVE)
      RelationshipReindexer.call(pid: pid, time_to_live: time_to_live)
      true
    end

    # @api public
    # @param pid [String]
    # @return Curate::Indexer::Document::PreservationDocument
    def self.find_preservation_document_by(pid)
      Preservation.find(pid)
    end

    # @api public
    # @param pid [String]
    # @return Curate::Indexer::Documents::IndexDocument
    def self.find_index_document_by(pid)
      Index.find(pid)
    end

    # @api public
    # @yield Curate::Indexer::Document::PreservationDocument
    def self.each_preservation_document
      Preservation.find_each { |document| yield(document) }
    end

    # @api public
    # @param pid [String]
    # @yield Curate::Indexer::Documents::IndexDocument
    def self.each_child_document_of(pid, &block)
      Index.each_child_document_of(pid, &block)
    end

    class << self
      # Here because I made a previous declaration that .reindex was part of the
      # public API. Then I decided I didn't want to use that method.
      alias reindex reindex_relationships
    end

    # @api public
    # Responsible for reindexing the entire preservation layer.
    # @param time_to_live [Integer] - there to guard against cyclical graphs
    # @return [Boolean] - It was successful
    # @raise Curate::Exceptions::CycleDetectionError - A potential cycle was detected
    def self.reindex_all!(time_to_live = DEFAULT_TIME_TO_LIVE)
      RepositoryReindexer.call(time_to_live: time_to_live, pid_reindexer: method(:reindex_relationships))
      true
    end

    # @api private
    # This is not something that I envision using in the production environment;
    # It is hear to keep the Preservation system isolated and accessible only through interfaces.
    # @return Curate::Indexer::Documents::PreservationDocument
    def self.write_document_attributes_to_preservation_layer(attributes = {})
      Preservation.write_document(attributes)
    end

    # @api private
    # @return Curate::Indexer::Documents::IndexDocument
    def self.write_document_attributes_to_index_layer(attributes = {})
      Index.write_document(attributes)
    end
  end
end
