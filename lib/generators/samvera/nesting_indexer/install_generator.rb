# frozen_string_literal: true

require 'rails/generators/base'

module Samvera
  module NestingIndexer
    module Generators
      # Responsible for exposing the install generator (e.g. rails generator install amvera:nesting_indexer:install)
      class InstallGenerator < Rails::Generators::Base
        DEFAULT_MAXIMUM_NESTING_DEPTH = 5
        source_root File.expand_path('templates', __dir__)
        desc "Creates a Samvera::NestingIndexer initializer."
        class_option(
          :adapter,
          aliases: '-a',
          desc: "The class name of your adapter that implements the Samvera::NestingIndexer::Adapter interface",
          required: false,
          type: :string
        )
        class_option(
          :depth,
          aliases: '-d',
          default: DEFAULT_MAXIMUM_NESTING_DEPTH,
          desc: "The maximum nesting depth of documents",
          required: false,
          type: :numeric
        )

        def copy_initializer
          @adapter_class_name = options.key?(:adapter) ? options[:adapter].classify : ''
          @maximum_nesting_depth = options.fetch(:depth).to_i
          template "samvera-nesting_indexer_initializer.rb", "config/initializers/samvera-nesting_indexer_initializer.rb"
        end

        def show_readme
          readme "README" if behavior == :invoke
        end
      end
    end
  end
end
