# frozen_string_literal: true

require_relative "../cop_test_helper"
require_relative "../../../../lib/rubocop/cop/actions/no_domain_mutation"

class ActionsNoDomainMutationTest < Minitest::Test
  include CopTestHelper

  COP = RuboCop::Cop::Actions::NoDomainMutation

  def test_registers_offense_for_create_in_action_file
    offenses = inspect_action_source(<<~RUBY)
      class CommentsActions
        def new_form_for(parent)
          Comment.create!(parent:)
        end
      end
    RUBY

    assert_equal 1, offenses.size
    assert_equal message_for(COP), offenses.first.message
    assert_equal "create!", offenses.first.location.source
  end

  def test_registers_offense_for_background_job_in_action_file
    offenses = inspect_action_source(<<~RUBY)
      class ArticlesActions
        def publish_button(recording)
          PublishArticleJob.perform_later(recording)
        end
      end
    RUBY

    assert_equal 1, offenses.size
    assert_equal "perform_later", offenses.first.location.source
  end

  def test_allows_new_record_instances_for_forms
    offenses = inspect_action_source(<<~RUBY)
      class CommentsActions
        def new_form_for(parent)
          view.render "comments/form", comment: Comment.new
        end
      end
    RUBY

    assert_empty offenses
  end

  def test_allows_domain_mutation_calls_outside_action_files
    offenses = inspect_source(<<~RUBY, path: "app/controllers/comments_controller.rb", cop_class: COP)
      class CommentsController
        def create
          Comment.create!(comment_params)
        end
      end
    RUBY

    assert_empty offenses
  end

  private

  def inspect_action_source(source)
    inspect_source(source, path: "app/actions/comments_actions.rb", cop_class: COP)
  end
end
