require "test_helper"

class GuestPersonTest < ActiveSupport::TestCase
  setup do
    @guest = GuestPerson.new
    @bucket = Current.bucket
  end

  test "has no persisted identity" do
    assert_nil @guest.id
    assert_nil @guest.person_card
    assert @guest.guest?
  end

  test "has no bucket memberships" do
    assert_empty @guest.buckets
    assert_nil @guest.membership_for(@bucket)
    refute @guest.member_of?(@bucket)
  end

  test "does not have any bucket roles" do
    refute @guest.viewer_of?(@bucket)
    refute @guest.editor_of?(@bucket)
    refute @guest.admin_of?(@bucket)
  end
end
