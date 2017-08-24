require 'rails/railtie'

module Samvera
  module NestingIndexer
    # Connect into the boot sequence of a Rails application
    class Railtie < Rails::Railtie
      config.to_prepare do
        Samvera::NestingIndexer.configure!
      end
    end
  end
end
