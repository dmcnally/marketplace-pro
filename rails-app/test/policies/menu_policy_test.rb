require "test_helper"
require_relative "../test_helpers/catalogue_test_helper"

class MenuPolicyTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  test "only editors and admins may manage menus within their bucket" do
    menu = create_catalogue_menu
    policy = MenuPolicy.new(person: Current.person, bucket: Current.bucket)
    refute policy.can_create?
    membership = Membership.create!(person: Current.person, bucket: Current.bucket, role: :viewer)
    refute policy.can_view?(menu)
    %i[editor admin].each do |role|
      membership.update!(role: role)
      assert policy.can_create?
      assert policy.can_view?(menu)
      assert policy.can_edit?(menu)
    end
    other = create_catalogue_menu(bucket: Bucket.create!(name: "Other"))
    refute policy.can_view?(other)
    refute policy.can_edit?(other)
    refute MenuPolicy.new(person: GuestPerson.new, bucket: Current.bucket).can_view?(menu)
    section = add_menu_section(menu)
    assert section.viewable_by?(Current.person)
    refute section.deletable_by?(Current.person)
    assert_raises(ArgumentError) { policy.can_edit?(section) }
    menu.reload.archive_content!(revision: menu.draft_revision)
    refute policy.can_edit?(menu)
    refute section.reload.editable_by?(Current.person)
  end
end
