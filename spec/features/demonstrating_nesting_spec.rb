require 'spec_helper'
require 'samvera/nesting_indexer'
require 'samvera/nesting_indexer/exceptions'
require 'samvera/nesting_indexer/adapters'
require 'support/feature_spec_support_methods'

# :nodoc:
module Samvera
  module NestingIndexer
    RSpec.describe 'Demonstrating nesting' do
      include Support::FeatureSpecSupportMethods
      before do
        NestingIndexer.adapter.clear_cache!
      end

      # Check if a document can be nested within itself.
      def allowed_to_nest?(child_id:, parent_id:)
        return false if child_id == parent_id # quick short circuit; don't let a parent be it's own child.
        parent = NestingIndexer.adapter.find_index_document_by(id: parent_id)
        # The more complicated test case. Check the parent such that the given child is not part of the parent's ancestry.
        return false if parent.ancestors.detect { |pathname| pathname.include?(child_id) }
        true
      end

      def verify_allowed_parent_ids(id:, allowed_parent_ids:)
        actual_allowed = []
        NestingIndexer.adapter.each_index_document do |document|
          if allowed_to_nest?(child_id: id, parent_id: document.id)
            actual_allowed += [document.id]
          end
        end
        expect(actual_allowed.sort).to eq(allowed_parent_ids.sort)
      end

      context 'querying what other documents in which the given document can nest' do
        [
          {
            label: "a simple non-nested graph",
            starting_graph: { parent_ids: { a: [], b: [], c: [] } },
            expectations: [
              { id: 'a', allowed_parent_ids: ['b', 'c'] },
              { id: 'b', allowed_parent_ids: ['a', 'c'] },
              { id: 'c', allowed_parent_ids: ['a', 'b'] }
            ]
          }, {
            label: 'an already nested simple nested graph',
            starting_graph: { parent_ids: { a: [], b: ['a'], c: ['b'] } },
            expectations: [
              { id: 'a', allowed_parent_ids: [] },
              { id: 'b', allowed_parent_ids: ['a'] },
              { id: 'c', allowed_parent_ids: ['a', 'b'] }
            ]
          }, {
            label: 'a semi-complicated nested graph',
            starting_graph: { parent_ids: { a: [], b: ['a'], c: ['a', 'b'], d: ['c', 'e'], e: ['b'], g: [] } },
            expectations: [
              { id: 'a', allowed_parent_ids: ['g'] },
              { id: 'b', allowed_parent_ids: ['g', 'a'] },
              { id: 'c', allowed_parent_ids: ['g', 'a', 'b', 'e'] },
              { id: 'd', allowed_parent_ids: ['g', 'a', 'b', 'c', 'e'] },
              { id: 'e', allowed_parent_ids: ['g', 'a', 'b', 'c'] },
              { id: 'g', allowed_parent_ids: ['a', 'b', 'c', 'd', 'e'] }
            ]
          }
        ].each do |the_scenario|
          it "works for #{the_scenario.fetch(:label)}" do
            build_graph(the_scenario.fetch(:starting_graph))
            NestingIndexer.reindex_all!
            the_scenario.fetch(:expectations).each do |expectation|
              verify_allowed_parent_ids(expectation)
            end
          end
        end
      end
    end
  end
end
