module IndividualNodeIndexer
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
  def self.call(nodes)
    nodes.each_pair do |pid, member_of|
      Curate::Indexer::Persistence::Document.new(pid: pid, member_of: member_of)
      Curate::Indexer.reindex(pid: pid)
    end
    # If we don't clear the processing cache, we'll be obliterating the previous work
    Curate::Indexer::Processing.clear_cache!
  end
end
