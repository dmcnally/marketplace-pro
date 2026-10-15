require "test_helper"

class PersonCardRecordingPolicyTest < ActiveSupport::TestCase
  setup do
    @bucket = Current.bucket
    @person = Current.person
    @recording = @person.recording
  end

  test "editable? allows the owner" do
    Membership.create!(person: @person, bucket: @bucket, role: :viewer)

    assert policy_for(@person).editable?
  end

  test "editable? allows admins who are not the owner" do
    other_person = create_person(first_name: "Admin", last_name: "User")
    Membership.create!(person: other_person, bucket: @bucket, role: :admin)

    assert policy_for(other_person).editable?
  end

  test "editable? denies editors who are not the owner" do
    other_person = create_person(first_name: "Editor", last_name: "User")
    Membership.create!(person: other_person, bucket: @bucket, role: :editor)

    refute policy_for(other_person).editable?
  end

  test "deletable? allows admins" do
    Membership.create!(person: @person, bucket: @bucket, role: :admin)

    assert policy_for(@person).deletable?
  end

  test "deletable? denies the owner when not an admin" do
    Membership.create!(person: @person, bucket: @bucket, role: :editor)

    refute policy_for(@person).deletable?
  end

  test "viewable? uses the default policy" do
    Membership.create!(person: @person, bucket: @bucket, role: :viewer)

    assert policy_for(@person).viewable?
  end

  test "viewable? allows the owner without bucket membership" do
    assert policy_for(@person).viewable?
  end

  private

  def policy_for(person)
    PersonCardRecordingPolicy.new(person:, recording: @recording)
  end

  def create_person(first_name:, last_name:)
    person_card = PersonCard.create!(first_name:, last_name:)
    recording = Current.bucket.recordings.create!(recordable: person_card)

    Person.create!(recording:)
  end
end
