require "test_helper"

class Admin::ActionsTest < ActiveSupport::TestCase
  setup do
    @view = FakeAdminView.new
  end

  test "header link renders for bucket admins" do
    Membership.create!(person: Current.person, bucket: Current.bucket, role: :admin)
    actions = Admin::Actions.new(view: @view, person: Current.person, bucket: Current.bucket)

    assert_equal(
      { label: "Admin", path: "/admin", options: { class: "site-header__link" } },
      actions.header_link
    )
  end

  test "header link does not render for non-admins" do
    Membership.create!(person: Current.person, bucket: Current.bucket, role: :editor)
    actions = Admin::Actions.new(view: @view, person: Current.person, bucket: Current.bucket)

    assert_nil actions.header_link
  end

  class FakeAdminView
    def link_to(label, path, options = {})
      { label:, path:, options: }
    end

    def admin_root_path
      "/admin"
    end
  end
end
