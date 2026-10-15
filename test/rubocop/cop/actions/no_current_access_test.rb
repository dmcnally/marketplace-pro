# frozen_string_literal: true

require "minitest/autorun"
require "rubocop"
require_relative "../../../../lib/rubocop/cop/actions/no_current_access"

class ActionsNoCurrentAccessTest < Minitest::Test
  COP_NAME = RuboCop::Cop::Actions::NoCurrentAccess.cop_name
  MSG = "#{COP_NAME}: #{RuboCop::Cop::Actions::NoCurrentAccess::MSG}"

  def test_registers_offense_for_current_access_in_action_file
    offenses = inspect_source(<<~RUBY, path: "app/actions/articles_actions.rb")
      class ArticlesActions
        def edit_link
          Current.person
        end
      end
    RUBY

    assert_equal 1, offenses.size
    assert_equal MSG, offenses.first.message
    assert_equal 3, offenses.first.line
    assert_equal "Current", offenses.first.location.source
  end

  def test_registers_offense_for_current_assignment_in_action_file
    offenses = inspect_source(<<~RUBY, path: "app/actions/session_actions.rb")
      class SessionActions
        def sign_in(session)
          Current.session = session
        end
      end
    RUBY

    assert_equal 1, offenses.size
    assert_equal MSG, offenses.first.message
    assert_equal 3, offenses.first.line
    assert_equal "Current", offenses.first.location.source
  end

  def test_registers_offense_for_absolute_current_access_in_namespaced_action_file
    offenses = inspect_source(<<~RUBY, path: "/app/root/app/actions/admin/sidebar_actions.rb")
      class Admin::SidebarActions
        def links
          ::Current.bucket
        end
      end
    RUBY

    assert_equal 1, offenses.size
    assert_equal MSG, offenses.first.message
    assert_equal 3, offenses.first.line
    assert_equal "::Current", offenses.first.location.source
  end

  def test_registers_offense_for_safe_navigation_current_access
    offenses = inspect_source(<<~RUBY, path: "app/actions/admin/actions.rb")
      class Admin::Actions
        def active?
          Current&.person
        end
      end
    RUBY

    assert_equal 1, offenses.size
    assert_equal MSG, offenses.first.message
    assert_equal 3, offenses.first.line
    assert_equal "Current", offenses.first.location.source
  end

  def test_allows_current_access_outside_action_files
    offenses = inspect_source(<<~RUBY, path: "app/controllers/articles_controller.rb")
      class ArticlesController < ApplicationController
        def policy
          Current.person
        end
      end
    RUBY

    assert_empty offenses
  end

  def test_allows_current_named_local_variable_in_action_file
    offenses = inspect_source(<<~RUBY, path: "app/actions/articles_actions.rb")
      class ArticlesActions
        def edit_link(current)
          current.person
        end
      end
    RUBY

    assert_empty offenses
  end

  private

  def inspect_source(source, path:)
    processed_source = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, path)
    cop = RuboCop::Cop::Actions::NoCurrentAccess.new(RuboCop::Config.new)
    RuboCop::Cop::Commissioner.new([ cop ]).investigate(processed_source).offenses
  end
end
