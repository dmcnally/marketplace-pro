require "test_helper"

module Admin
  class MembersControllerTest < ActionDispatch::IntegrationTest
    test "index lists members for the current bucket" do
      user = users(:two)
      Membership.create!(person: user.person, bucket: buckets(:default), role: :admin)
      sign_in_as user

      get admin_members_path

      assert_response :success
      assert_select "h1", "Members"
      assert_select ".management-sidebar__link--active", "Members"
      assert_select ".member-list__name", people(:two).person_card.name
      assert_select ".member-list__meta", user.email_address
      assert_select ".member-list__role", "Admin"
      assert_select ".member-list__meta", { text: users(:one).email_address, count: 0 }
    end

    test "index redirects guests to sign in" do
      get admin_members_path

      assert_redirected_to new_session_path
    end

    test "index forbids signed-in non-admins" do
      user = users(:two)
      Membership.create!(person: user.person, bucket: buckets(:default), role: :viewer)
      sign_in_as user

      get admin_members_path

      assert_response :forbidden
    end
  end
end
