require "test_helper"

class ApprovalTest < ActiveSupport::TestCase
  include CsvImportTestHelper

  setup do
    @person = Current.person
    @import = create_csv_import(processed: true)
  end

  test "requires a subject for the approval" do
    approval = Approval.new(person: @person)

    refute approval.valid?
    assert_includes approval.errors[:approvable], "must exist"
  end

  test "starts a new approval as pending" do
    approval = Approval.create!(approvable: @import, person: @person)

    assert_equal "pending", approval.reload.status
  end

  test "returns the recorded person as the creator" do
    approval = Approval.create!(approvable: @import, person: @person)

    Current.set(person: users(:two).person) do
      assert_equal @person, approval.creator
    end
  end

  test "uses the bucket of the subject being approved" do
    approval = Approval.create!(approvable: @import, person: @person)

    Current.set(bucket: buckets(:default)) do
      assert_equal @import.bucket, approval.bucket
    end
  end

  test "records the initial approval status in the event history" do
    approval = Approval.create!(approvable: @import, person: @person)

    approval_event = approval.events.sole

    assert_equal "pending", approval_event.action
    assert_equal @import, approval_event.subject
    assert_equal @import.bucket, approval_event.bucket
    assert_equal @person, approval_event.person
  end

  test "records status changes with the approval's person and subject" do
    approval = Approval.create!(approvable: @import, person: @person)

    Current.set(person: users(:two).person, bucket: buckets(:default)) do
      approval.update!(status: "approving")
    end

    approval_event = approval.events.order(:id).last

    assert_equal 2, approval.events.count
    assert_equal "approving", approval_event.action
    assert_equal @import, approval_event.subject
    assert_equal @import.bucket, approval_event.bucket
    assert_equal @person, approval_event.person
  end

  test "does not add an event when the approval status has not changed" do
    approval = Approval.create!(approvable: @import, person: @person)

    assert_no_difference -> { approval.events.count } do
      approval.save!
    end
  end
end
