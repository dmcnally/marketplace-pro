# frozen_string_literal: true

require_relative "../project/action_policy_helpers"

module RuboCop
  module Cop
    module Policies
      # Prevent policies from mutating state or rendering responses.
      class NoSideEffects < Base
        include Project::ActionPolicyHelpers

        MSG = "Keep policies side-effect free; policies should only answer permission questions."

        def on_send(node)
          return unless policies_file?
          return unless policy_side_effect?(node)

          add_offense(node.loc.selector)
        end
        alias on_csend on_send
      end
    end
  end
end
