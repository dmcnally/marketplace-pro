# frozen_string_literal: true

require_relative "../project/action_policy_helpers"

module RuboCop
  module Cop
    module Actions
      # Prevent action objects from reading request state directly.
      class NoRequestStateAccess < Base
        include Project::ActionPolicyHelpers

        MSG = "Pass request context into actions instead of reading request state directly."

        def on_send(node)
          return unless actions_file?
          return unless request_state_access?(node)

          add_offense(node.loc.selector)
        end
        alias on_csend on_send
      end
    end
  end
end
