require "test_helper"

class CategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @bucket = Current.bucket
    @membership = Membership.create!(person: users(:two).person, bucket: @bucket, role: :editor)
    sign_in_as users(:two)
    @category = @bucket.recordings.create!(recordable: Category.new(name: "Starters", description: "Small plates"))
  end

  test "editor creates and edits immutable categories with actor and comparison history" do
    get admin_categories_path
    assert_response :success
    assert_select "h1", "Categories"
    assert_select "a", text: "Add category"

    assert_difference -> { @bucket.recordings.categories.count }, 1 do
      post admin_categories_path, params: { category: { name: "Drinks" } }
    end
    assert_redirected_to admin_categories_path
    original = @category.recordable
    patch admin_category_path(@category), params: { revision: @category.draft_revision, category: { name: "Sharing", description: "For two" } }
    assert_redirected_to admin_categories_path
    assert_equal "Starters", original.reload.name
    assert_equal "Sharing", @category.reload.recordable.name
    event = @category.events.find_by!(action: "updated")
    assert_equal users(:two).person, event.person
    assert_equal original, event.subject_previous
    get admin_category_path(@category)
    assert_response :success
    assert_select "del", text: "Starters"
    assert_select "ins", text: "Sharing"
  end

  test "invalid create and edit show errors and preserve input without saving" do
    assert_no_difference "Category.count" do
      post admin_categories_path, params: { category: { name: "", description: "Keep this" } }
    end
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /Name can't be blank/
    assert_select "textarea", text: "Keep this"

    assert_no_difference "Category.count" do
      patch admin_category_path(@category), params: { revision: @category.draft_revision, category: { name: "", description: "Still here" } }
    end
    assert_response :unprocessable_entity
    assert_select "textarea", text: "Still here"
    assert_equal "Starters", @category.reload.recordable.name
  end

  test "archive and restore preserve content and record events" do
    content = @category.recordable
    post admin_category_archive_path(@category), params: { revision: @category.draft_revision }
    assert_response :see_other
    assert @category.reload.discarded?
    get admin_categories_path
    assert_select "strong", text: "Starters", count: 0
    get admin_categories_path(archived: "1")
    assert_select "button", text: "Restore category"
    delete admin_category_archive_path(@category), params: { revision: @category.draft_revision }
    assert_response :see_other
    assert @category.reload.kept?
    assert_equal content, @category.recordable
    assert_equal %w[created discarded restored], @category.events.order(:id).pluck(:action)
  end

  test "stale and missing revisions cannot overwrite or archive newer content" do
    stale = @category.draft_revision
    @category.revise_content!({ name: "New name" }, revision: stale)
    patch admin_category_path(@category), params: { revision: stale, category: { name: "Lost update" } }
    assert_response :conflict
    assert_select "h1", "Your draft has changed"
    post admin_category_archive_path(@category), params: { revision: stale }
    assert_response :conflict
    patch admin_category_path(@category), params: { category: { name: "No revision" } }
    assert_response :conflict
    assert_equal "New name", @category.reload.recordable.name
    assert @category.kept?
  end

  test "viewer cannot access management or mutate categories even through direct requests" do
    @membership.update!(role: :viewer)
    get admin_categories_path
    assert_response :forbidden
    get edit_admin_category_path(@category)
    assert_response :forbidden
    get admin_category_path(@category)
    assert_response :forbidden
    get recording_diff_path(@category)
    assert_response :forbidden
    assert_no_difference "Category.count" do
      post admin_categories_path, params: { category: { name: "Forbidden" } }
      assert_response :forbidden
      patch admin_category_path(@category), params: { revision: @category.draft_revision, category: { name: "Forbidden" } }
      assert_response :forbidden
    end
    post admin_category_archive_path(@category), params: { revision: @category.draft_revision }
    assert_response :forbidden
    @category.archive_content!(revision: @category.draft_revision)
    delete admin_category_archive_path(@category), params: { revision: @category.draft_revision }
    assert_response :forbidden
    assert @category.reload.discarded?
  end

  test "other buckets and other recordable types cannot be accessed through category routes" do
    foreign = Bucket.create!(name: "Other shop").recordings.create!(recordable: Category.new(name: "Private"))
    article = @bucket.recordings.create!(recordable: Article.new(title: "Wrong type"))
    [ foreign, article ].each do |recording|
      get admin_category_path(recording)
      assert_response :not_found
      post admin_category_archive_path(recording), params: { revision: recording.draft_revision }
      assert_response :not_found
    end
  end

  test "guests are directed to sign in" do
    sign_out
    get admin_categories_path
    assert_redirected_to new_session_path
  end
end
