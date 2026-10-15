require "test_helper"

class PermissibleTest < ActiveSupport::TestCase
  setup do
    @bucket = Current.bucket
    @person = Current.person
  end

  # Person role helper methods

  test "member_of? returns true when person has membership in bucket" do
    Membership.create!(person: @person, bucket: @bucket, role: :viewer)

    assert @person.member_of?(@bucket)
  end

  test "member_of? returns false when person has no membership in bucket" do
    other_bucket = Bucket.create!(name: "Other Bucket")

    refute @person.member_of?(other_bucket)
  end

  test "viewer_of? returns true for any membership" do
    Membership.create!(person: @person, bucket: @bucket, role: :viewer)

    assert @person.viewer_of?(@bucket)
  end

  test "editor_of? returns true for editor role" do
    Membership.create!(person: @person, bucket: @bucket, role: :editor)

    assert @person.editor_of?(@bucket)
  end

  test "editor_of? returns true for admin role" do
    Membership.create!(person: @person, bucket: @bucket, role: :admin)

    assert @person.editor_of?(@bucket)
  end

  test "editor_of? returns false for viewer role" do
    Membership.create!(person: @person, bucket: @bucket, role: :viewer)

    refute @person.editor_of?(@bucket)
  end

  test "admin_of? returns true for admin role" do
    Membership.create!(person: @person, bucket: @bucket, role: :admin)

    assert @person.admin_of?(@bucket)
  end

  test "admin_of? returns false for editor role" do
    Membership.create!(person: @person, bucket: @bucket, role: :editor)

    refute @person.admin_of?(@bucket)
  end

  # Recording permissions use policy classes

  test "recording.editable_by? uses the default policy when no specialized policy exists" do
    Membership.create!(person: @person, bucket: @bucket, role: :editor)
    article = Article.new(title: "Test Article")
    recording = Current.bucket.recordings.create!(recordable: article)

    assert recording.editable_by?(@person)
  end

  test "recording.viewable_by? uses the default policy when no specialized policy exists" do
    Membership.create!(person: @person, bucket: @bucket, role: :viewer)
    article = Article.new(title: "Test Article")
    recording = Current.bucket.recordings.create!(recordable: article)

    assert recording.viewable_by?(@person)
  end

  test "recording.editable_by? uses a specialized policy when one exists" do
    other_person = create_person(first_name: "Editor", last_name: "User")
    Membership.create!(person: other_person, bucket: @bucket, role: :editor)

    refute @person.recording.editable_by?(other_person)
  end

  private

  def create_person(first_name:, last_name:)
    person_card = PersonCard.create!(first_name:, last_name:)
    recording = Current.bucket.recordings.create!(recordable: person_card)

    Person.create!(recording:)
  end
end
