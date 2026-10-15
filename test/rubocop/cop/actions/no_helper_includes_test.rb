# frozen_string_literal: true

require_relative "../cop_test_helper"
require_relative "../../../../lib/rubocop/cop/actions/no_helper_includes"

class ActionsNoHelperIncludesTest < Minitest::Test
  include CopTestHelper

  COP = RuboCop::Cop::Actions::NoHelperIncludes

  def test_registers_offense_for_helper_include_in_action_file
    offenses = inspect_action_source(<<~RUBY)
      class ArticlesActions
        include ApplicationHelper
      end
    RUBY

    assert_equal 1, offenses.size
    assert_equal message_for(COP), offenses.first.message
    assert_equal "include ApplicationHelper", offenses.first.location.source
  end

  def test_registers_offense_for_route_helper_include_in_action_file
    offenses = inspect_action_source(<<~RUBY)
      class ArticlesActions
        include Rails.application.routes.url_helpers
      end
    RUBY

    assert_equal 1, offenses.size
    assert_equal "include Rails.application.routes.url_helpers", offenses.first.location.source
  end

  def test_allows_non_helper_include
    offenses = inspect_action_source(<<~RUBY)
      class ArticlesActions
        include Presentable
      end
    RUBY

    assert_empty offenses
  end

  def test_allows_helper_include_outside_action_files
    offenses = inspect_source(<<~RUBY, path: "app/controllers/articles_controller.rb", cop_class: COP)
      class ArticlesController
        include ApplicationHelper
      end
    RUBY

    assert_empty offenses
  end

  private

  def inspect_action_source(source)
    inspect_source(source, path: "app/actions/articles_actions.rb", cop_class: COP)
  end
end
