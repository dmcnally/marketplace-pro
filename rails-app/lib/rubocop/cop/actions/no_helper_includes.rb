# frozen_string_literal: true

require_relative "../project/action_policy_helpers"

module RuboCop
  module Cop
    module Actions
      # Prevent action objects from mixing in helper modules.
      class NoHelperIncludes < Base
        include Project::ActionPolicyHelpers

        MSG = "Call helpers through the injected view object instead of including helper modules."

        def on_send(node)
          return unless actions_file?
          return unless node.command?(:include)
          return unless helper_include?(node)

          add_offense(node)
        end

        private

        def helper_include?(node)
          node.arguments.any? do |argument|
            source = argument.source
            source.end_with?("Helper") || source == "Rails.application.routes.url_helpers"
          end
        end
      end
    end
  end
end
