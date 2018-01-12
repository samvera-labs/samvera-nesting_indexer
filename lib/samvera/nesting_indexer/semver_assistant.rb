require 'set'
module Samvera
  module NestingIndexer
    # @api private
    # A service object responsible for coordinating declarations of interface changes
    module SemverAssistant
      def self.messages
        @messages ||= Set.new
      end

      def self.removing_from_public_api(context:, as_of:)
        message = "As of version #{as_of}, #{context} will be removed from the public API"
        messages << message
        ActiveSupport::Deprecation.warn(message, caller[1..-1]) if defined?(ActiveSupport::Deprecation) && !ENV.key?('SKIP_ACTIVE_SUPPORT_DEPRECATION')
      end
    end
  end
end
Samvera::NestingIndexer.private_constant :SemverAssistant
