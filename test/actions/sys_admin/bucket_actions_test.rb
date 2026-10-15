require "test_helper"

class SysAdmin::BucketActionsTest < ActiveSupport::TestCase
  setup do
    @person = Current.person
    @bucket = buckets(:default)
    @view = FakeBucketsView.new
    Membership.create!(person: @person, bucket: buckets(:system), role: :admin)
  end

  test "bucket actions render for sys admins" do
    actions = SysAdmin::BucketActions.new(view: @view, person: @person)

    assert actions.index_link
    assert actions.new_link
    assert actions.edit_link_for(@bucket)
    assert actions.switch_button_for(@bucket)
  end

  test "bucket actions do not render for guests" do
    actions = SysAdmin::BucketActions.new(view: @view, person: GuestPerson.new)

    assert_nil actions.index_link
    assert_nil actions.new_link
    assert_nil actions.edit_link_for(@bucket)
    assert_nil actions.switch_button_for(@bucket)
  end

  test "switch button does not render for the system bucket" do
    actions = SysAdmin::BucketActions.new(view: @view, person: @person)

    assert_nil actions.switch_button_for(buckets(:system))
  end

  test "switch button does not render for the identity bucket" do
    actions = SysAdmin::BucketActions.new(view: @view, person: @person)

    assert_nil actions.switch_button_for(buckets(:identity))
  end

  class FakeBucketsView
    def link_to(label, path, options = {})
      { label:, path:, options: }
    end

    def button_to(label, path, options = {})
      { label:, path:, options: }
    end

    def new_sys_admin_bucket_path
      "/sys_admin/buckets/new"
    end

    def sys_admin_buckets_path
      "/sys_admin/buckets"
    end

    def edit_sys_admin_bucket_path(bucket)
      "/sys_admin/buckets/#{bucket.id}/edit"
    end

    def bucket_switch_path(bucket)
      "/buckets/#{bucket.id}/switch"
    end
  end
end
