# frozen_string_literal: true

module RuboCop
  module Cop
    module Project
      module ActionPolicyHelpers
        REQUEST_STATE_METHODS = %i[
          cookies
          flash
          params
          request
          response
          session
        ].freeze

        SIDE_EFFECT_METHODS = %i[
          create
          create!
          delete
          deliver_later
          destroy
          destroy!
          enqueue
          perform_later
          redirect_to
          render
          save
          save!
          update
          update!
        ].freeze

        ACTION_SIDE_EFFECT_METHODS = (SIDE_EFFECT_METHODS - %i[render redirect_to]).freeze

        def actions_file?
          processed_source.path.to_s.match?(%r{(^|/)app/actions/.+\.rb\z})
        end

        def policies_file?
          processed_source.path.to_s.match?(%r{(^|/)app/policies/.+\.rb\z})
        end

        def request_state_access?(node)
          REQUEST_STATE_METHODS.include?(node.method_name)
        end

        def policy_side_effect?(node)
          SIDE_EFFECT_METHODS.include?(node.method_name)
        end

        def action_side_effect?(node)
          ACTION_SIDE_EFFECT_METHODS.include?(node.method_name)
        end
      end
    end
  end
end
