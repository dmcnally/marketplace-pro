require "test_helper"

class ArticlesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:two)
  end

  test "new allows bucket admins" do
    add_current_membership(role: :admin)

    get new_article_path

    assert_response :success
  end

  test "new forbids non-admin bucket members" do
    sign_in_as users(:two)
    add_current_membership(user: users(:two), role: :editor)

    get new_article_path

    assert_response :forbidden
  end

  test "create allows bucket admins" do
    add_current_membership(role: :admin)

    assert_difference -> { Recording.articles.count }, 1 do
      post articles_path, params: { article: { title: "Authorized Article", body: "Body" } }
    end

    assert_redirected_to Recording.articles.order(:created_at).last
  end

  test "create forbids non-admin bucket members" do
    sign_in_as users(:two)
    add_current_membership(user: users(:two), role: :editor)

    assert_no_difference -> { Recording.articles.count } do
      post articles_path, params: { article: { title: "Forbidden Article", body: "Body" } }
    end

    assert_response :forbidden
  end

  test "show renders edit and publish actions for signed-in bucket admins" do
    add_current_membership(role: :admin)
    recording = create_article_recording

    get article_path(recording)

    assert_response :success
    assert_select ".site-header__nav > a[href='#{admin_root_path}']", text: "Admin"
    assert_select ".site-header__menu a[href='#{admin_root_path}']", count: 0
    assert_select "a", text: "Edit"
    assert_select "button", text: "Publish"
    assert_select "form.comment-form"
  end

  test "show hides protected actions for guests" do
    sign_out
    Current.bucket = Bucket.content.first
    recording = create_article_recording

    get article_path(recording)

    assert_response :success
    assert_select "a", { text: "Edit", count: 0 }
    assert_select "button", { text: "Publish", count: 0 }
    assert_select "form.comment-form", count: 0
    assert_select ".comment-sign-in-required__message", text: "Must be signed in to comment."
  end

  test "sys admin banner shows exit bucket without dashboard when switched into a bucket" do
    content_bucket = Current.bucket
    sign_out
    sign_in_as users(:one)
    post bucket_switch_path(content_bucket)

    get articles_path

    assert_response :success
    assert_select ".site-header__bucket", content_bucket.name
    assert_select ".site-header__user", users(:one).email_address
    assert_select ".sys-admin-banner__label", "Sys Admin"
    assert_select ".sys-admin-banner__link[href='#{sys_admin_dashboard_path}']", count: 0
    assert_select "form[action='#{bucket_switch_path(content_bucket)}'] button", text: "Exit Bucket"
    assert_select ".site-header__menu a[href='#{sys_admin_dashboard_path}']", count: 0
  end

  test "sys admin without a selected bucket is redirected to bucket selection" do
    sign_out
    sign_in_as users(:one)

    get articles_path

    assert_redirected_to sys_admin_buckets_path
  end

  test "sys admin banner is hidden for signed-in non-sys-admins" do
    sign_out
    sign_in_as users(:two)
    add_current_membership(user: users(:two), role: :viewer)

    get articles_path

    assert_response :success
    assert_select ".sys-admin-banner", count: 0
    assert_select "a", { text: "Dashboard", count: 0 }
  end

  test "sys admin banner is hidden for guests" do
    sign_out

    get articles_path

    assert_response :success
    assert_select ".sys-admin-banner", count: 0
    assert_select "a", { text: "Dashboard", count: 0 }
  end

  test "redirects signed-in non-sys-admins without content buckets to the error page" do
    sign_out
    sign_in_as users(:two)

    get articles_path

    assert_redirected_to no_bucket_path
  end

  test "uses the content bucket stored in the session cookie" do
    sign_out
    preferred_bucket = Bucket.create!(name: "Preferred")
    Membership.create!(person: users(:two).person, bucket: preferred_bucket, role: :viewer)
    sign_in_as users(:two)

    get articles_path

    assert_response :success
    assert_select ".site-header__bucket", preferred_bucket.name

    Membership.create!(person: users(:two).person, bucket: buckets(:default), role: :viewer)

    get articles_path

    assert_response :success
    assert_select ".site-header__bucket", preferred_bucket.name
  end

  test "falls back when the session bucket cannot be loaded" do
    sign_out
    preferred_bucket = Bucket.create!(name: "Temporary")
    membership = Membership.create!(person: users(:two).person, bucket: preferred_bucket, role: :viewer)
    sign_in_as users(:two)

    get articles_path

    assert_response :success
    assert_select ".site-header__bucket", preferred_bucket.name

    membership.destroy!
    Membership.create!(person: users(:two).person, bucket: buckets(:default), role: :viewer)

    get articles_path

    assert_response :success
    assert_select ".site-header__bucket", buckets(:default).name
  end

  test "edit allows bucket admins" do
    add_current_membership(role: :admin)
    recording = create_article_recording

    get edit_article_path(recording)

    assert_response :success
  end

  test "edit forbids non-admin bucket members" do
    sign_in_as users(:two)
    add_current_membership(user: users(:two), role: :editor)
    recording = create_article_recording

    get edit_article_path(recording)

    assert_response :forbidden
  end

  test "update allows bucket admins" do
    add_current_membership(role: :admin)
    recording = create_article_recording(title: "Original Title")

    patch article_path(recording), params: { article: { title: "Updated Title", body: "Updated body" } }

    assert_redirected_to recording
    assert_equal "Updated Title", recording.reload.recordable.title
  end

  test "update forbids non-admin bucket members" do
    sign_in_as users(:two)
    add_current_membership(user: users(:two), role: :editor)
    recording = create_article_recording(title: "Original Title")

    patch article_path(recording), params: { article: { title: "Updated Title", body: "Updated body" } }

    assert_response :forbidden
    assert_equal "Original Title", recording.reload.recordable.title
  end

  test "destroy allows bucket admins" do
    add_current_membership(role: :admin)
    recording = create_article_recording

    delete article_path(recording)

    assert_redirected_to articles_path
    assert recording.reload.discarded?
  end

  test "destroy forbids non-admin bucket members" do
    sign_in_as users(:two)
    add_current_membership(user: users(:two), role: :editor)
    recording = create_article_recording

    delete article_path(recording)

    assert_response :forbidden
    refute recording.reload.discarded?
  end

  private

  def add_current_membership(role:, user: users(:two))
    Membership.create!(person: user.person, bucket: Current.bucket, role:)
  end

  def create_article_recording(title: "Existing Article", body: "Existing body")
    Current.bucket.recordings.create!(recordable: Article.new(title:, body:))
  end
end
