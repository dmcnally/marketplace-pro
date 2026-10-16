require "test_helper"
require_relative "../test_helpers/catalogue_test_helper"

class ProductPolicyTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  test "publication requires an editor in the owning bucket and appropriate lifecycle state" do
    product = create_catalogue_product
    policy = ProductPolicy.new(person: Current.person, bucket: Current.bucket)
    refute policy.can_publish?(product)
    membership = Membership.create!(person: Current.person, bucket: Current.bucket, role: :viewer)
    refute policy.can_publish?(product)
    %i[editor admin].each do |role|
      membership.update!(role: role)
      assert policy.can_publish?(product)
      refute policy.can_unpublish?(product)
      refute policy.can_revert?(product)
    end
    publication = Product::Publication.new(product)
    publication.publish!(token: publication.review_token)
    assert policy.can_unpublish?(product)
    assert policy.can_revert?(product)
    publication.unpublish!(token: publication.review_token)
    refute policy.can_unpublish?(product)
    assert policy.can_revert?(product)
    other = create_catalogue_product(bucket: Bucket.create!(name: "Other"))
    refute policy.can_publish?(other)
    refute ProductPolicy.new(person: GuestPerson.new, bucket: Current.bucket).can_publish?(product)
    product.archive_content!(revision: product.draft_revision)
    refute policy.can_publish?(product)
    refute policy.can_unpublish?(product)
    refute policy.can_revert?(product)
    assert_raises(ArgumentError) { policy.can_publish?(product.children.variants.sole) }
  end
end
