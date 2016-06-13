module Curate
  module Indexer
    # @api private
    #
    # A module mixin to expose rudimentary read/write capabilities
    #
    # @example
    #   module Foo
    #     extend Curate::Indexer::StorageModule
    #   end
    module StorageModule
      def write(doc)
        cache[doc.pid] = doc
      end

      def find(pid)
        cache.fetch(pid.to_s)
      end

      def find_each
        cache.each { |_key, document| yield(document) }
      end

      def clear_cache!
        @cache = {}
      end

      def cache
        @cache ||= {}
      end
      private :cache
    end
  end
end
