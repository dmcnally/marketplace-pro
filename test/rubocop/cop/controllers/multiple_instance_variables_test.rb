require "test_helper"
require_relative "../cop_test_helper"
require_relative "../../../../lib/rubocop/cop/controllers/multiple_instance_variables"

class ControllersMultipleInstanceVariablesTest < ActiveSupport::TestCase
  include CopTestHelper

  COP = RuboCop::Cop::Controllers::MultipleInstanceVariables

  test "reports an action that assigns two different instance variables" do
    offenses = inspect_controller(<<~RUBY)
      class ArticlesController
        def index
          @articles = []
          @bucket = nil
        end
      end
    RUBY

    assert_equal 1, offenses.size
    assert_equal "index", offenses.first.location.source
    assert_equal message_for(COP), offenses.first.message
  end

  test "allows an action that assigns one instance variable" do
    offenses = inspect_controller(<<~RUBY)
      class ArticlesController
        def show
          @article = Article.first
        end
      end
    RUBY

    assert_empty offenses
  end

  test "allows repeated assignments to the same instance variable" do
    offenses = inspect_controller(<<~RUBY)
      class ArticlesController
        def show
          @article = nil
          @article = Article.first
        end
      end
    RUBY

    assert_empty offenses
  end

  test "allows an action without instance variable assignments" do
    offenses = inspect_controller(<<~RUBY)
      class ArticlesController
        def destroy
          Article.first.destroy!
        end
      end
    RUBY

    assert_empty offenses
  end

  test "counts instance variables assigned inside blocks" do
    offenses = inspect_controller(<<~RUBY)
      class ArticlesController
        def index
          @articles = []
          Article.find_each { |article| @article = article }
        end
      end
    RUBY

    assert_equal 1, offenses.size
  end

  test "counts instance variables assigned inside conditions" do
    offenses = inspect_controller(<<~RUBY)
      class ArticlesController
        def show
          @article = Article.first
          @bucket = @article.bucket if @article
        end
      end
    RUBY

    assert_equal 1, offenses.size
  end

  test "checks each action separately" do
    offenses = inspect_controller(<<~RUBY)
      class ArticlesController
        def index
          @articles = []
        end

        def show
          @article = Article.first
        end
      end
    RUBY

    assert_empty offenses
  end

  test "allows multiple instance variables in a nonstandard action" do
    offenses = inspect_controller(<<~RUBY)
      class ArticlesController
        def preview
          @article = Article.first
          @bucket = @article.bucket
        end
      end
    RUBY

    assert_empty offenses
  end

  test "ignores files outside the controllers directory" do
    offenses = inspect_controller(
      <<~RUBY,
        class ArticlesController
          def index
            @articles = []
            @bucket = nil
          end
        end
      RUBY
      path: "app/services/articles_controller.rb"
    )

    assert_empty offenses
  end

  test "checks controllers in a namespace" do
    offenses = inspect_controller(
      <<~RUBY,
        class Admin::ArticlesController
          def index
            @articles = []
            @bucket = nil
          end
        end
      RUBY
      path: "app/controllers/admin/articles_controller.rb"
    )

    assert_equal 1, offenses.size
  end

  test "checks every standard controller action" do
    %w[index show new create edit update destroy].each do |action|
      offenses = inspect_controller(<<~RUBY)
        class ArticlesController
          def #{action}
            @article = nil
            @bucket = nil
          end
        end
      RUBY

      assert_equal 1, offenses.size, "Expected an offense for #{action}"
    end
  end

  private

  def inspect_controller(source, path: "app/controllers/articles_controller.rb")
    inspect_source(source, path: path, cop_class: COP)
  end
end
