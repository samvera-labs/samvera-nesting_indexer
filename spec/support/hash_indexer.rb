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

  def self.clear_all_caches!
    Curate::Indexer::Index::Query.clear_cache!
    Curate::Indexer::Persistence.clear_cache!
    Curate::Indexer::Processing.clear_cache!
  end

  def self.end_of_recursion?(graph, rebuilder)
    return false unless graph.empty?
    Curate::Indexer::Processing.clear_cache!
    rebuilder.send(:cache).each do |key, _document|
      Curate::Indexer.reindex(pid: key)
    end
    true
  end
  private_class_method :end_of_recursion?

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
  private_class_method :associate
end
