require "test_helper"
require_relative "../test_helpers/catalogue_test_helper"

class AvailabilityPolicyTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  test "all member roles can operate only visible variants of products on the live published menu" do
    product = create_catalogue_product
    variant = product.children.variants.sole
    policy = AvailabilityPolicy.new(availability: Catalogue::Availability.new(person: Current.person, bucket: Current.bucket))
    refute policy.can_view?
    refute policy.can_change_product?(product)
    membership = Membership.create!(person: Current.person, bucket: Current.bucket, role: :viewer)
    assert policy.can_view?
    refute policy.can_change_variant?(variant)
    publication = Product::Publication.new(product)
    publication.publish!(token: publication.review_token)
    refute policy.can_change_product?(product)
    menu = create_catalogue_menu
    add_menu_section(menu, product_ids: [ product.id ])
    refute policy.can_change_product?(product)
    publication = Menu::Publication.new(menu.reload)
    publication.publish!(token: publication.review_token)
    %i[viewer editor admin].each do |role|
      membership.update!(role: role)
      assert policy.can_change_product?(product)
      assert policy.can_change_variant?(variant)
    end
    refute policy.can_change_variant?(product)
    refute policy.can_change_product?(variant)
    refute AvailabilityPolicy.new(availability: Catalogue::Availability.new(person: GuestPerson.new, bucket: Current.bucket)).can_view?
    foreign_policy = AvailabilityPolicy.new(availability: Catalogue::Availability.new(person: Current.person, bucket: Bucket.create!(name: "Other")))
    refute foreign_policy.can_change_variant?(variant)
    product.archive_content!(revision: product.reload.draft_revision)
    refute policy.can_change_product?(product)
    refute policy.can_change_variant?(variant)
  end
end
