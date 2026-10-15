require "test_helper"

class PublicationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @article = Article.new(title: "Test Article", body: "Test body")
    @recording = Current.bucket.recordings.create!(recordable: @article)
    sign_in_as users(:two)
  end

  test "create allows bucket admins to publish the recording" do
    add_current_membership(role: :admin)
    refute @recording.published?

    post publication_path, params: publication_params_for(@recording)

    @recording.reload
    assert @recording.published?
    assert_response :success
  end

  test "create forbids non-admin bucket members" do
    sign_in_as users(:two)
    add_current_membership(user: users(:two), role: :editor)

    post publication_path, params: publication_params_for(@recording)

    assert_response :forbidden
    refute @recording.reload.published?
  end

  test "create forbids recordables without a publication policy" do
    comment_recording = @recording.children.create!(recordable: Comment.new(body: "Test comment"))
    add_current_membership(role: :admin)

    post publication_path, params: publication_params_for(comment_recording)

    assert_response :forbidden
    refute comment_recording.reload.published?
  end

  test "create responds with turbo_stream" do
    add_current_membership(role: :admin)

    post publication_path, params: publication_params_for(@recording), as: :turbo_stream

    assert_response :success
    assert_match "turbo-stream", response.body
  end

  test "destroy allows bucket admins to unpublish the recording" do
    add_current_membership(role: :admin)
    @recording.publish!
    assert @recording.published?

    delete publication_path, params: publication_params_for(@recording)

    @recording.reload
    refute @recording.published?
    assert_response :success
  end

  test "destroy forbids non-admin bucket members" do
    sign_in_as users(:two)
    add_current_membership(user: users(:two), role: :editor)
    @recording.publish!

    delete publication_path, params: publication_params_for(@recording)

    assert_response :forbidden
    assert @recording.reload.published?
  end

  test "destroy responds with turbo_stream" do
    add_current_membership(role: :admin)
    @recording.publish!

    delete publication_path, params: publication_params_for(@recording), as: :turbo_stream

    assert_response :success
    assert_match "turbo-stream", response.body
  end

  test "create returns not found for an invalid signed publishable" do
    add_current_membership(role: :admin)

    post publication_path, params: { publishable: "invalid" }

    assert_response :not_found
  end

  private

  def add_current_membership(role:, user: users(:two))
    Membership.create!(person: user.person, bucket: Current.bucket, role:)
  end

  def publication_params_for(publishable)
    {
      publishable: publishable.to_sgid(for: "publication", expires_in: nil).to_s
    }
  end
end
