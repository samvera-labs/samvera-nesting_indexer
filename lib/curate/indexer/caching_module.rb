module Curate
  # Responsible for the indexing strategy of related objects
  module Indexer
    # There are several layers of caching involved, this provides some of the common behavior.
    module CachingModule
      def find(key, &block)
        cache.fetch(key, &block)
      end

      def cache
        @cache ||= {}
      end

      def add_to_cache(key, value)
        cache[key] ||= value
      end

      def clear_cache!
        @cache = {}
      end
    end
    private_constant :CachingModule
  end
end
