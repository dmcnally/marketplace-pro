# frozen_string_literal: true

require "minitest/autorun"
require "rubocop"
require_relative "../../../../lib/rubocop/cop/policies/no_current_access"

class PoliciesNoCurrentAccessTest < Minitest::Test
  COP_NAME = RuboCop::Cop::Policies::NoCurrentAccess.cop_name
  MSG = "#{COP_NAME}: #{RuboCop::Cop::Policies::NoCurrentAccess::MSG}"

  def test_registers_offense_for_current_access_in_policy_file
    offenses = inspect_source(<<~RUBY, path: "app/policies/article_policy.rb")
      class ArticlePolicy
        def can_create?
          Current.person.admin?
        end
      end
    RUBY

    assert_equal 1, offenses.size
    assert_equal MSG, offenses.first.message
    assert_equal 3, offenses.first.line
    assert_equal "Current", offenses.first.location.source
  end

  def test_registers_offense_for_current_assignment_in_policy_file
    offenses = inspect_source(<<~RUBY, path: "app/policies/default_recording_policy.rb")
      class DefaultRecordingPolicy
        def viewable?
          Current.bucket = recording.bucket
        end
      end
    RUBY

    assert_equal 1, offenses.size
    assert_equal MSG, offenses.first.message
    assert_equal 3, offenses.first.line
    assert_equal "Current", offenses.first.location.source
  end

  def test_registers_offense_for_absolute_current_access_in_policy_file
    offenses = inspect_source(<<~RUBY, path: "/app/root/app/policies/person_card_recording_policy.rb")
      class PersonCardRecordingPolicy
        def owner?
          ::Current.person == person
        end
      end
    RUBY

    assert_equal 1, offenses.size
    assert_equal MSG, offenses.first.message
    assert_equal 3, offenses.first.line
    assert_equal "::Current", offenses.first.location.source
  end

  def test_registers_offense_for_safe_navigation_current_access
    offenses = inspect_source(<<~RUBY, path: "app/policies/recordable_policy.rb")
      class RecordablePolicy
        def bucket_admin?
          Current&.person&.admin_of?(bucket)
        end
      end
    RUBY

    assert_equal 1, offenses.size
    assert_equal MSG, offenses.first.message
    assert_equal 3, offenses.first.line
    assert_equal "Current", offenses.first.location.source
  end

  def test_allows_current_access_outside_policy_files
    offenses = inspect_source(<<~RUBY, path: "app/controllers/articles_controller.rb")
      class ArticlesController < ApplicationController
        def policy
          Current.person
        end
      end
    RUBY

    assert_empty offenses
  end

  def test_allows_current_named_local_variable_in_policy_file
    offenses = inspect_source(<<~RUBY, path: "app/policies/article_policy.rb")
      class ArticlePolicy
        def can_create?(current)
          current.person.admin?
        end
      end
    RUBY

    assert_empty offenses
  end

  private

  def inspect_source(source, path:)
    processed_source = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, path)
    cop = RuboCop::Cop::Policies::NoCurrentAccess.new(RuboCop::Config.new)
    RuboCop::Cop::Commissioner.new([ cop ]).investigate(processed_source).offenses
  end
end
