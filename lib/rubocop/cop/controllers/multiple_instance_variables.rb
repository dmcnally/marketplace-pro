# frozen_string_literal: true

module RuboCop
  module Cop
    module Controllers
      # Prevent standard controller actions from assigning multiple view objects.
      class MultipleInstanceVariables < Base
        STANDARD_ACTIONS = %i[index show new create edit update destroy].freeze
        MSG = "This standard controller action assigns more than one instance variable. " \
          "Are you potentially missing a domain concept that could encapsulate them?"

        def on_def(node)
          return unless controller_file?
          return unless STANDARD_ACTIONS.include?(node.method_name)
          return unless assigned_instance_variables(node).length > 1

          add_offense(node.loc.name)
        end

        private

        def controller_file?
          processed_source.path.to_s.match?(%r{(^|/)app/controllers/.+_controller\.rb\z})
        end

        def assigned_instance_variables(node)
          node.each_descendant(:ivasgn)
            .select { |assignment| assignment.each_ancestor(:def, :defs).first.equal?(node) }
            .map(&:name)
            .uniq
        end
      end
    end
  end
end
