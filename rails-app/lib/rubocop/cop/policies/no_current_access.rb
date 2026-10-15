# frozen_string_literal: true

require_relative "../project/action_policy_helpers"

module RuboCop
  module Cop
    module Policies
      # Prevent policy objects from depending on Current directly.
      class NoCurrentAccess < Base
        include Project::ActionPolicyHelpers

        MSG = "Pass required context into policies instead of reading Current directly."

        def_node_matcher :current_const?, <<~PATTERN
          (const {nil? cbase} :Current)
        PATTERN

        def on_send(node)
          return unless policies_file?
          return unless current_const?(node.receiver)

          add_offense(node.receiver)
        end
        alias on_csend on_send
      end
    end
  end
end
