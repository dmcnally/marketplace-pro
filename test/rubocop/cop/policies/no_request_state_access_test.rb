# frozen_string_literal: true

require_relative "../cop_test_helper"
require_relative "../../../../lib/rubocop/cop/policies/no_request_state_access"

class PoliciesNoRequestStateAccessTest < Minitest::Test
  include CopTestHelper

  COP = RuboCop::Cop::Policies::NoRequestStateAccess

  def test_registers_offense_for_params_access_in_policy_file
    offenses = inspect_policy_source(<<~RUBY)
      class ArticlePolicy
        def can_edit?(recording)
          params[:id] == recording.id
        end
      end
    RUBY

    assert_equal 1, offenses.size
    assert_equal message_for(COP), offenses.first.message
    assert_equal "params", offenses.first.location.source
  end

  def test_registers_offense_for_request_access_in_policy_file
    offenses = inspect_policy_source(<<~RUBY)
      class ArticlePolicy
        def can_edit?(recording)
          request.path.include?(recording.id.to_s)
        end
      end
    RUBY

    assert_equal 1, offenses.size
    assert_equal "request", offenses.first.location.source
  end

  def test_allows_request_state_access_outside_policy_files
    offenses = inspect_source(<<~RUBY, path: "app/controllers/articles_controller.rb", cop_class: COP)
      class ArticlesController
        def show
          params[:id]
        end
      end
    RUBY

    assert_empty offenses
  end

  def test_allows_local_variable_named_request
    offenses = inspect_policy_source(<<~RUBY)
      class ArticlePolicy
        def can_edit?(request)
          request.path?
        end
      end
    RUBY

    assert_empty offenses
  end

  private

  def inspect_policy_source(source)
    inspect_source(source, path: "app/policies/article_policy.rb", cop_class: COP)
  end
end
