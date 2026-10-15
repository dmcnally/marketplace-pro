# frozen_string_literal: true

module RuboCop
  module Cop
    module Recordables
      # Prevent direct Recording model access outside tests.
      class NoDirectRecordingAccess < Base
        MSG = "Scope recordings through a bucket instead of calling Recording directly."

        def_node_matcher :recording_const?, <<~PATTERN
          (const {nil? cbase} :Recording)
        PATTERN

        def on_send(node)
          receiver = node.receiver
          return unless receiver
          return unless recording_const?(receiver)

          add_offense(receiver)
        end
      end
    end
  end
end
