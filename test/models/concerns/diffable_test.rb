require "test_helper"

class DiffableTest < ActiveSupport::TestCase
  test "recordables are diffable by default" do
    assert Article.new(title: "Title").diffable?
  end

  test "recordable fields exclude technical columns" do
    assert_includes Article.recordable_fields, "title"
    assert_includes Article.recordable_fields, "body"
    assert_not_includes Article.recordable_fields, "id"
    assert_not_includes Article.recordable_fields, "created_at"
    assert_not_includes Article.recordable_fields, "updated_at"
  end
end
