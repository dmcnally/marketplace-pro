# frozen_string_literal: true

require_relative "../cop_test_helper"
require_relative "../../../../lib/rubocop/cop/policies/no_side_effects"

class PoliciesNoSideEffectsTest < Minitest::Test
  include CopTestHelper

  COP = RuboCop::Cop::Policies::NoSideEffects

  def test_registers_offense_for_update_in_policy_file
    offenses = inspect_policy_source(<<~RUBY)
      class ArticlePolicy
        def can_edit?(recording)
          recording.update!(authorized: true)
        end
      end
    RUBY

    assert_equal 1, offenses.size
    assert_equal message_for(COP), offenses.first.message
    assert_equal "update!", offenses.first.location.source
  end

  def test_registers_offense_for_render_in_policy_file
    offenses = inspect_policy_source(<<~RUBY)
      class ArticlePolicy
        def can_edit?(recording)
          render "forbidden"
        end
      end
    RUBY

    assert_equal 1, offenses.size
    assert_equal "render", offenses.first.location.source
  end

  def test_registers_offense_for_job_enqueue_in_policy_file
    offenses = inspect_policy_source(<<~RUBY)
      class ArticlePolicy
        def can_edit?(recording)
          AuditJob.perform_later(recording)
        end
      end
    RUBY

    assert_equal 1, offenses.size
    assert_equal "perform_later", offenses.first.location.source
  end

  def test_allows_predicate_queries
    offenses = inspect_policy_source(<<~RUBY)
      class ArticlePolicy
        def can_edit?(recording)
          recording.publishable? && person.admin_of?(bucket)
        end
      end
    RUBY

    assert_empty offenses
  end

  def test_allows_side_effect_calls_outside_policy_files
    offenses = inspect_source(<<~RUBY, path: "app/controllers/articles_controller.rb", cop_class: COP)
      class ArticlesController
        def update
          @article.update!(article_params)
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
