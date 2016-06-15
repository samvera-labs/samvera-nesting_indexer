require 'rails/railtie'

module Curate
  module Indexer
    # Connect into the boot sequence of a Rails application
    class Railtie < Rails::Railtie
      config.eager_load_namespaces << Curate::Indexer
      config.to_prepare do
        Curate::Indexer.send(:configure!)
      end
    end
  end
end
