require "test_helper"

class ArticlePolicyTest < ActiveSupport::TestCase
  setup do
    @bucket = Current.bucket
    @person = Current.person
  end

  test "write actions allow bucket admins" do
    Membership.create!(person: @person, bucket: @bucket, role: :admin)
    recording = create_recording(Article.new(title: "Test Article"))

    assert policy.can_create?
    assert policy.can_edit?(recording)
    assert policy.can_delete?(recording)
  end

  test "write actions deny bucket editors" do
    Membership.create!(person: @person, bucket: @bucket, role: :editor)
    recording = create_recording(Article.new(title: "Test Article"))

    refute policy.can_create?
    refute policy.can_edit?(recording)
    refute policy.can_delete?(recording)
  end

  test "can_publish? allows bucket admins to publish articles" do
    Membership.create!(person: @person, bucket: @bucket, role: :admin)
    recording = create_recording(Article.new(title: "Test Article"))

    assert policy.can_publish?(recording)
  end

  test "can_publish? denies bucket editors" do
    Membership.create!(person: @person, bucket: @bucket, role: :editor)
    recording = create_recording(Article.new(title: "Test Article"))

    refute policy.can_publish?(recording)
  end

  test "can_publish? denies bucket viewers" do
    Membership.create!(person: @person, bucket: @bucket, role: :viewer)
    recording = create_recording(Article.new(title: "Test Article"))

    refute policy.can_publish?(recording)
  end

  test "can_comment_on? allows bucket members to comment on commentable articles" do
    Membership.create!(person: @person, bucket: @bucket, role: :viewer)
    recording = create_recording(Article.new(title: "Test Article"))

    assert policy.can_comment_on?(recording)
  end

  test "can_comment_on? denies guests" do
    recording = create_recording(Article.new(title: "Test Article"))
    guest_policy = ArticlePolicy.new(person: GuestPerson.new, bucket: @bucket)

    refute guest_policy.can_comment_on?(recording)
  end

  test "can_publish? rejects non-article recordings" do
    recording = create_recording(Comment.new(body: "Test comment"))

    error = assert_raises(ArgumentError) do
      policy.can_publish?(recording)
    end

    assert_equal "ArticlePolicy cannot authorize Comment", error.message
  end

  private

  def policy
    ArticlePolicy.new(person: @person, bucket: @bucket)
  end

  def create_recording(recordable)
    return Current.bucket.recordings.create!(recordable:) unless recordable.is_a?(Comment)

    parent_recording = Current.bucket.recordings.create!(recordable: Article.new(title: "Parent Article"))
    parent_recording.children.create!(recordable:)
  end
end
