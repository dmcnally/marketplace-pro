# frozen_string_literal: true

require_relative "../project/action_policy_helpers"

module RuboCop
  module Cop
    module Policies
      # Prevent policies from depending on request state.
      class NoRequestStateAccess < Base
        include Project::ActionPolicyHelpers

        MSG = "Pass authorization context into policies instead of reading request state."

        def on_send(node)
          return unless policies_file?
          return unless request_state_access?(node)

          add_offense(node.loc.selector)
        end
        alias on_csend on_send
      end
    end
  end
end
