require "test_helper"

class ApplicationControllerAuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:two)
    @bucket = buckets(:default)
  end

  test "allows a protected request when the signed-in person has permission" do
    sign_in_with_role(:admin)

    get new_admin_csv_import_path

    assert_response :success
    assert_select "h1", text: "New Import"
  end

  test "forbids a protected request when the signed-in person lacks permission" do
    sign_in_with_role(:viewer)

    get new_admin_csv_import_path

    assert_response :forbidden
  end

  test "redirects guests to sign in before accessing a protected page" do
    get new_admin_csv_import_path

    assert_redirected_to new_session_path
  end

  test "forbids a command when no authorization policy exists" do
    sign_in_with_role(:admin)
    article_recording = @bucket.recordings.create!(
      recordable: Article.new(title: "Example article")
    )
    comment_recording = article_recording.children.create!(
      recordable: Comment.new(body: "Example comment")
    )

    assert_no_difference "Publication.count" do
      post publication_path, params: {
        publishable: comment_recording.to_sgid(
          for: "publication",
          expires_in: nil
        ).to_s
      }
    end

    assert_response :forbidden
    refute comment_recording.reload.published?
  end

  test "denies access after switching to a bucket where the person is a viewer" do
    sign_in_with_role(:admin)
    other_bucket = Bucket.create!(name: "Other")
    Membership.create!(
      person: @user.person,
      bucket: other_bucket,
      role: :viewer
    )

    post bucket_switch_path(other_bucket)

    assert_redirected_to root_path

    get new_admin_csv_import_path

    assert_response :forbidden
  end

  test "allows access after switching to a bucket where the person is an admin" do
    sign_in_with_role(:viewer)
    other_bucket = Bucket.create!(name: "Other")
    Membership.create!(
      person: @user.person,
      bucket: other_bucket,
      role: :admin
    )

    post bucket_switch_path(other_bucket)

    assert_redirected_to root_path

    get new_admin_csv_import_path

    assert_response :success
    assert_select "h1", text: "New Import"
  end

  private

  def sign_in_with_role(role)
    Membership.create!(person: @user.person, bucket: @bucket, role: role)
    sign_in_as @user
  end
end
