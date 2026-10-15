require "test_helper"

class SysAdmin::ActionsTest < ActiveSupport::TestCase
  setup do
    @view = FakeSysAdminView.new
    Membership.create!(person: Current.person, bucket: buckets(:system), role: :admin)
  end

  test "banner exit bucket button renders for sys admins with a selected bucket" do
    actions = SysAdmin::Actions.new(view: @view, person: Current.person, bucket: Current.bucket)

    assert_equal(
      {
        label: "Exit Bucket",
        path: "/buckets/#{Current.bucket.id}/switch",
        options: {
          method: :delete,
          class: "sys-admin-banner__link sys-admin-banner__button",
          form_class: "sys-admin-banner__form"
        }
      },
      actions.banner_exit_bucket_button
    )
  end

  test "banner exit bucket button does not render without a selected bucket" do
    actions = SysAdmin::Actions.new(view: @view, person: Current.person, bucket: nil)

    assert_nil actions.banner_exit_bucket_button
  end

  test "banner exit bucket button does not render for guests" do
    actions = SysAdmin::Actions.new(view: @view, person: GuestPerson.new, bucket: Current.bucket)

    assert_nil actions.banner_exit_bucket_button
  end

  class FakeSysAdminView
    def button_to(label, path, options = {})
      { label:, path:, options: }
    end

    def bucket_switch_path(bucket)
      "/buckets/#{bucket.id}/switch"
    end
  end
end
