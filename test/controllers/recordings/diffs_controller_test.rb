require "test_helper"

class Recordings::DiffsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:two)
    @membership = Membership.create!(person: users(:two).person, bucket: Current.bucket, role: :viewer)
  end

  test "authorized users can view the diff screen" do
    recording = create_article_recording
    recording.update!(recordable: Article.new(title: "Updated title", body: "Updated body"))

    get recording_diff_path(recording)

    assert_response :success
    assert_select "h1", "Compare Article Changes"
  end

  test "unauthorized users are forbidden" do
    guest_bucket = Bucket.content.order(:id).first
    recording = guest_bucket.recordings.create!(
      recordable: Article.new(title: "Guest-visible title", body: "Guest-visible body")
    )
    sign_out

    get recording_diff_path(recording)

    assert_response :forbidden
  end

  test "recordings are scoped through current bucket" do
    other_bucket = Bucket.create!(name: "Other")
    other_recording = other_bucket.recordings.create!(
      recordable: Article.new(title: "Other title", body: "Other body")
    )

    get recording_diff_path(other_recording)

    assert_response :not_found
  end

  test "no previous version renders an empty state" do
    recording = create_article_recording

    get recording_diff_path(recording)

    assert_response :success
    assert_select ".empty-state__message", "No previous version."
  end

  test "changed fields render previous and current values" do
    recording = create_article_recording(title: "Original title", body: "Original body")
    recording.update!(recordable: Article.new(title: "Updated title", body: "Updated body"))

    get recording_diff_path(recording)

    assert_response :success
    assert_select ".recordable-diff__field-name", text: "Title"
    assert_select ".recordable-diff__field-name", text: "Body"
    assert_select ".recordable-diff .html-diff ins", text: /Updated/
  end

  private

  def create_article_recording(title: "Existing title", body: "Existing body")
    Current.bucket.recordings.create!(recordable: Article.new(title:, body:))
  end
end
