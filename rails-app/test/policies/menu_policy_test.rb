require "test_helper"
require_relative "../test_helpers/catalogue_test_helper"

class MenuPolicyTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  test "archive and restore require an editor and the corresponding archive state" do
    menu = create_catalogue_menu
    policy = MenuPolicy.new(person: Current.person, bucket: Current.bucket)
    refute policy.can_archive?(menu)
    membership = Membership.create!(person: Current.person, bucket: Current.bucket, role: :editor)
    assert policy.can_archive?(menu)
    refute policy.can_restore?(menu)
    menu.archive_content!(revision: menu.draft_revision)
    refute policy.can_archive?(menu)
    assert policy.can_restore?(menu)
    membership.update!(role: :viewer)
    refute policy.can_restore?(menu)
  end

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
      assert policy.can_publish?(menu)
      refute policy.can_unpublish?(menu)
      refute policy.can_revert?(menu)
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

  test "unpublish and revert permissions reflect the independent publication lifecycle" do
    Membership.create!(person: Current.person, bucket: Current.bucket, role: :editor)
    menu = create_catalogue_menu
    product = create_catalogue_product
    publication = Product::Publication.new(product)
    publication.publish!(token: publication.review_token)
    add_menu_section(menu, product_ids: [ product.id ])
    publication = Menu::Publication.new(menu.reload)
    publication.publish!(token: publication.review_token)
    policy = MenuPolicy.new(person: Current.person, bucket: Current.bucket)
    assert policy.can_unpublish?(menu)
    assert policy.can_revert?(menu)
    publication.unpublish!(token: publication.review_token)
    refute policy.can_unpublish?(menu)
    assert policy.can_revert?(menu)
  end
end
