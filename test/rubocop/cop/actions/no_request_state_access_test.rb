# frozen_string_literal: true

require_relative "../cop_test_helper"
require_relative "../../../../lib/rubocop/cop/actions/no_request_state_access"

class ActionsNoRequestStateAccessTest < Minitest::Test
  include CopTestHelper

  COP = RuboCop::Cop::Actions::NoRequestStateAccess

  def test_registers_offense_for_params_access_in_action_file
    offenses = inspect_action_source(<<~RUBY)
      class ArticlesActions
        def edit_link
          params[:id]
        end
      end
    RUBY

    assert_equal 1, offenses.size
    assert_equal message_for(COP), offenses.first.message
    assert_equal "params", offenses.first.location.source
  end

  def test_registers_offense_for_view_session_access_in_action_file
    offenses = inspect_action_source(<<~RUBY)
      class SessionActions
        def sign_out_button
          view.session[:user_id]
        end
      end
    RUBY

    assert_equal 1, offenses.size
    assert_equal "session", offenses.first.location.source
  end

  def test_allows_request_state_access_outside_action_files
    offenses = inspect_source(<<~RUBY, path: "app/controllers/articles_controller.rb", cop_class: COP)
      class ArticlesController
        def show
          params[:id]
        end
      end
    RUBY

    assert_empty offenses
  end

  def test_allows_local_variable_named_params
    offenses = inspect_action_source(<<~RUBY)
      class ArticlesActions
        def edit_link(params)
          params[:id]
        end
      end
    RUBY

    assert_empty offenses
  end

  private

  def inspect_action_source(source)
    inspect_source(source, path: "app/actions/articles_actions.rb", cop_class: COP)
  end
end
