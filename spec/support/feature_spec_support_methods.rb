module Support
  module FeatureSpecSupportMethods
    def build_graph(graph)
      # Create the starting_graph
      graph.fetch(:parent_ids).each_key do |id|
        build_preservation_document(id, graph)
        build_index_document(id, graph)
      end
    end

    def build_preservation_document(id, graph)
      parent_ids = graph.fetch(:parent_ids).fetch(id)
      Samvera::NestingIndexer.adapter.write_document_attributes_to_preservation_layer(id: id, parent_ids: parent_ids)
    end

    def build_index_document(id, graph)
      nesting_document = Samvera::NestingIndexer::Documents::IndexDocument.new(
        id: id,
        parent_ids: graph.fetch(:parent_ids).fetch(id),
        ancestors: graph.fetch(:ancestors, {})[id],
        pathnames: graph.fetch(:pathnames, {})[id]
      )
      Samvera::NestingIndexer.adapter.write_nesting_document_to_index_layer(nesting_document: nesting_document)
    end

    # Logic that mirrors the behavior of updating an ActiveFedora object.
    def write_document_to_persistence_layers(preservation_document_attributes_to_update)
      Samvera::NestingIndexer.adapter.write_document_attributes_to_preservation_layer(preservation_document_attributes_to_update)
      attributes = { pathnames: [], ancestors: [] }.merge(preservation_document_attributes_to_update)
      nesting_document = Samvera::NestingIndexer::Documents::IndexDocument.new(**attributes)
      Samvera::NestingIndexer.adapter.write_nesting_document_to_index_layer(nesting_document: nesting_document)
    end

    def verify_graph_versus_storage(ending_graph)
      ending_graph.fetch(:parent_ids).each_key do |id|
        verify_graph_item_versus_storage(id, ending_graph)
      end
    end

    def verify_graph_item_versus_storage(id, ending_graph)
      document = Samvera::NestingIndexer::Documents::IndexDocument.new(
        id: id,
        parent_ids: ending_graph.fetch(:parent_ids).fetch(id),
        ancestors: ending_graph.fetch(:ancestors).fetch(id),
        pathnames: ending_graph.fetch(:pathnames).fetch(id)
      )
      expect(Samvera::NestingIndexer.adapter.find_index_document_by(id: id)).to eq(document)
    end
  end
end
