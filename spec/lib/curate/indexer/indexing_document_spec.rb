require 'spec_helper'
require 'curate/indexer/indexing_document'

module Curate
  module Indexer
    RSpec.describe IndexingDocument do
      subject { described_class.new(pid: 'A') }

      [:member_of, :transitive_member_of, :collection_members, :transitive_collection_members].each do |method_name|
        its(method_name) { should be_a(Array) }
        context "#add_#{method_name}" do
          context 'with an existing pid' do
            before { subject.public_send("add_#{method_name}", '1') }
            it "will not change the ##{method_name}" do
              expect { subject.public_send("add_#{method_name}", '1') }.to change { subject.public_send(method_name).count }.by(0)
            end
          end
          context 'with a new pid' do
            it "should change the ##{method_name}" do
              expect { subject.public_send("add_#{method_name}", %w(x y z p d q)) }.to(
                change { subject.public_send(method_name).count }.by(6)
              )
              expect { subject.public_send("add_#{method_name}", '12', '13') }.to(
                change { subject.public_send(method_name).count }.by(2)
              )
            end
          end
        end
      end
    end
  end
end
