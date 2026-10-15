# frozen_string_literal: true

require_relative "../project/action_policy_helpers"

module RuboCop
  module Cop
    module Actions
      # Prevent view-facing action objects from performing domain mutations.
      class NoDomainMutation < Base
        include Project::ActionPolicyHelpers

        MSG = "Keep actions view-facing; perform domain mutations in controllers, models, or services."

        def on_send(node)
          return unless actions_file?
          return unless action_side_effect?(node)

          add_offense(node.loc.selector)
        end
        alias on_csend on_send
      end
    end
  end
end
