# frozen_string_literal: true

require "minitest/autorun"
require "rubocop"

module CopTestHelper
  def inspect_source(source, path:, cop_class:)
    processed_source = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, path)
    cop = cop_class.new(RuboCop::Config.new)
    RuboCop::Cop::Commissioner.new([ cop ]).investigate(processed_source).offenses
  end

  def message_for(cop_class)
    "#{cop_class.cop_name}: #{cop_class::MSG}"
  end
end
