require "test_helper"

class AllergensControllerTest < ActionDispatch::IntegrationTest
  setup do
    @bucket = Current.bucket
    @membership = Membership.create!(person: users(:two).person, bucket: @bucket, role: :editor)
    sign_in_as users(:two)
    @allergen = @bucket.recordings.create!(recordable: Allergen.new(name: "Starters", description: "Small plates"))
  end

  test "editor creates and edits immutable allergens with actor and comparison history" do
    get admin_allergens_path
    assert_response :success
    assert_select "h1", "Allergens"
    assert_select "a", text: "Add allergen"

    assert_difference -> { @bucket.recordings.allergens.count }, 1 do
      post admin_allergens_path, params: { allergen: { name: "Drinks" } }
    end
    assert_redirected_to admin_allergens_path
    original = @allergen.recordable
    patch admin_allergen_path(@allergen), params: { revision: @allergen.draft_revision, allergen: { name: "Sharing", description: "For two" } }
    assert_redirected_to admin_allergens_path
    assert_equal "Starters", original.reload.name
    assert_equal "Sharing", @allergen.reload.recordable.name
    event = @allergen.events.find_by!(action: "updated")
    assert_equal users(:two).person, event.person
    assert_equal original, event.subject_previous
    get admin_allergen_path(@allergen)
    assert_response :success
    assert_select "del", text: "Starters"
    assert_select "ins", text: "Sharing"
  end

  test "invalid create and edit show errors and preserve input without saving" do
    assert_no_difference "Allergen.count" do
      post admin_allergens_path, params: { allergen: { name: "", description: "Keep this" } }
    end
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /Name can't be blank/
    assert_select "textarea", text: "Keep this"

    assert_no_difference "Allergen.count" do
      patch admin_allergen_path(@allergen), params: { revision: @allergen.draft_revision, allergen: { name: "", description: "Still here" } }
    end
    assert_response :unprocessable_entity
    assert_select "textarea", text: "Still here"
    assert_equal "Starters", @allergen.reload.recordable.name
  end

  test "archive and restore preserve content and record events" do
    content = @allergen.recordable
    post admin_allergen_archive_path(@allergen), params: { revision: @allergen.draft_revision }
    assert_response :see_other
    assert @allergen.reload.discarded?
    get admin_allergens_path
    assert_select "strong", text: "Starters", count: 0
    get admin_allergens_path(archived: "1")
    assert_select "button", text: "Restore allergen"
    delete admin_allergen_archive_path(@allergen), params: { revision: @allergen.draft_revision }
    assert_response :see_other
    assert @allergen.reload.kept?
    assert_equal content, @allergen.recordable
    assert_equal %w[created discarded restored], @allergen.events.order(:id).pluck(:action)
  end

  test "stale and missing revisions cannot overwrite or archive newer content" do
    stale = @allergen.draft_revision
    @allergen.revise_content!({ name: "New name" }, revision: stale)
    patch admin_allergen_path(@allergen), params: { revision: stale, allergen: { name: "Lost update" } }
    assert_response :conflict
    assert_select "h1", "Your draft has changed"
    post admin_allergen_archive_path(@allergen), params: { revision: stale }
    assert_response :conflict
    patch admin_allergen_path(@allergen), params: { allergen: { name: "No revision" } }
    assert_response :conflict
    assert_equal "New name", @allergen.reload.recordable.name
    assert @allergen.kept?
  end

  test "viewer cannot access management or mutate allergens even through direct requests" do
    @membership.update!(role: :viewer)
    get admin_allergens_path
    assert_response :forbidden
    get edit_admin_allergen_path(@allergen)
    assert_response :forbidden
    get admin_allergen_path(@allergen)
    assert_response :forbidden
    get recording_diff_path(@allergen)
    assert_response :forbidden
    assert_no_difference "Allergen.count" do
      post admin_allergens_path, params: { allergen: { name: "Forbidden" } }
      assert_response :forbidden
      patch admin_allergen_path(@allergen), params: { revision: @allergen.draft_revision, allergen: { name: "Forbidden" } }
      assert_response :forbidden
    end
    post admin_allergen_archive_path(@allergen), params: { revision: @allergen.draft_revision }
    assert_response :forbidden
    @allergen.archive_content!(revision: @allergen.draft_revision)
    delete admin_allergen_archive_path(@allergen), params: { revision: @allergen.draft_revision }
    assert_response :forbidden
    assert @allergen.reload.discarded?
  end

  test "other buckets and other recordable types cannot be accessed through allergen routes" do
    foreign = Bucket.create!(name: "Other shop").recordings.create!(recordable: Allergen.new(name: "Private"))
    article = @bucket.recordings.create!(recordable: Article.new(title: "Wrong type"))
    [ foreign, article ].each do |recording|
      get admin_allergen_path(recording)
      assert_response :not_found
      post admin_allergen_archive_path(recording), params: { revision: recording.draft_revision }
      assert_response :not_found
    end
  end

  test "guests are directed to sign in" do
    sign_out
    get admin_allergens_path
    assert_redirected_to new_session_path
  end
end
