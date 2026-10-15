require "test_helper"

class ArticlesActionsTest < ActiveSupport::TestCase
  setup do
    @bucket = Current.bucket
    @person = Current.person
    @recording = Current.bucket.recordings.create!(recordable: Article.new(title: "Test Article"))
    @view = FakeArticlesView.new
  end

  test "article actions render for bucket admins" do
    Membership.create!(person: @person, bucket: @bucket, role: :admin)

    actions = ArticlesActions.new(view: @view, person: @person, bucket: @bucket)

    assert actions.new_link
    assert actions.edit_link_for(@recording)
    assert actions.delete_button_for(@recording)
  end

  test "article actions do not render for non-admin bucket members" do
    Membership.create!(person: @person, bucket: @bucket, role: :editor)

    actions = ArticlesActions.new(view: @view, person: @person, bucket: @bucket)

    assert_nil actions.new_link
    assert_nil actions.edit_link_for(@recording)
    assert_nil actions.delete_button_for(@recording)
  end

  class FakeArticlesView
    def link_to(label, path, options = {})
      { label:, path:, options: }
    end

    def new_article_path
      "/articles/new"
    end

    def edit_article_path(article)
      "/articles/#{article.id}/edit"
    end

    def article_path(article)
      "/articles/#{article.id}"
    end
  end
end
