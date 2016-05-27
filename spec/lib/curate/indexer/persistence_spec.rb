require 'spec_helper'
require 'curate/indexer/persistence'

module Curate
  module Indexer
    module Persistence
      RSpec.describe Document do
        subject { described_class.new(pid: 'A', member_of: %w(1 2 3 4)) }

        its(:member_of) { should be_a(Array) }

        context '#add_member_of' do
          context 'with an existing member' do
            it 'will not change the #member_of' do
              expect { subject.add_member_of('1') }.to change { subject.member_of.count }.by(0)
            end
          end
          context 'with a new member' do
            it 'should change the #member_of' do
              expect { subject.add_member_of(%w(x y z p d q)) }.to change { subject.member_of.count }.by(6)
              expect { subject.add_member_of('12', '13') }.to change { subject.member_of.count }.by(2)
            end
          end
        end
      end
    end
  end
end
