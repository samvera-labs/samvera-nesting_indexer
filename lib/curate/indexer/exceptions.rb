module Curate
  module Indexer
    module Exceptions
      class RuntimeError < ::RuntimeError
      end
      class CycleDetectionError < RuntimeError
      end
    end
  end
end
