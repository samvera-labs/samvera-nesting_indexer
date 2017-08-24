require 'rails/railtie'

module Samvera
  module Indexer
    # Connect into the boot sequence of a Rails application
    class Railtie < Rails::Railtie
      config.to_prepare do
        Samvera::Indexer.configure!
      end
    end
  end
end
