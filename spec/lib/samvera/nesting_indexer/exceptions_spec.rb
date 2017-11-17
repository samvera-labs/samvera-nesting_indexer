require 'spec_helper'
require 'samvera/nesting_indexer/exceptions'

module Samvera
  module NestingIndexer
    module Exceptions
      RSpec.describe CycleDetectionError do
        subject { described_class.new(id: 123) }
        its(:to_s) { is_expected.to be_a(String) }
      end
    end
  end
end
