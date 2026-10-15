require "test_helper"

class DefaultRecordingPolicyTest < ActiveSupport::TestCase
  setup do
    @bucket = Current.bucket
    @person = Current.person
  end

  test "editable? allows editors" do
    Membership.create!(person: @person, bucket: @bucket, role: :editor)

    assert policy_for(Article.new(title: "Test Article")).editable?
  end

  test "editable? denies viewers" do
    Membership.create!(person: @person, bucket: @bucket, role: :viewer)

    refute policy_for(Comment.new(body: "Test comment")).editable?
  end

  test "deletable? allows admins" do
    Membership.create!(person: @person, bucket: @bucket, role: :admin)

    assert policy_for(Article.new(title: "Test Article")).deletable?
  end

  test "deletable? allows the creator" do
    Membership.create!(person: @person, bucket: @bucket, role: :viewer)

    assert policy_for(Comment.new(body: "Test comment")).deletable?
  end

  test "deletable? denies non-creator viewers" do
    other_person = create_person(first_name: "Other", last_name: "User")
    Membership.create!(person: other_person, bucket: @bucket, role: :viewer)

    refute policy_for(Article.new(title: "Test Article"), person: other_person).deletable?
  end

  test "viewable? allows viewers" do
    Membership.create!(person: @person, bucket: @bucket, role: :viewer)

    assert policy_for(Article.new(title: "Test Article")).viewable?
  end

  test "viewable? denies people without membership" do
    other_person = create_person(first_name: "Outside", last_name: "User")

    refute policy_for(Comment.new(body: "Test comment"), person: other_person).viewable?
  end

  private

  def policy_for(recordable, person: @person)
    recording = create_recording(recordable)

    DefaultRecordingPolicy.new(person:, recording:)
  end

  def create_recording(recordable)
    return Current.bucket.recordings.create!(recordable:) unless recordable.is_a?(Comment)

    parent_recording = Current.bucket.recordings.create!(recordable: Article.new(title: "Parent Article"))
    parent_recording.children.create!(recordable:)
  end

  def create_person(first_name:, last_name:)
    person_card = PersonCard.create!(first_name:, last_name:)
    recording = Current.bucket.recordings.create!(recordable: person_card)

    Person.create!(recording:)
  end
end
