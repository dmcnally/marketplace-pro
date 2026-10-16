require "test_helper"
require_relative "../test_helpers/catalogue_test_helper"

class ProductPolicyTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  test "archive permissions require ownership and state while variant restoration permits an archived parent" do
    product = create_catalogue_product
    variant = product.children.variants.sole
    other = create_catalogue_product
    policy = ProductPolicy.new(person: Current.person, bucket: Current.bucket)
    refute policy.can_archive?(product)
    refute policy.can_copy?(product)
    refute policy.can_archive_variant?(product, variant)
    membership = Membership.create!(person: Current.person, bucket: Current.bucket, role: :editor)
    assert policy.can_archive?(product)
    assert policy.can_copy?(product)
    assert policy.can_archive_variant?(product, variant)
    refute policy.can_archive_variant?(other, variant)
    refute policy.can_restore?(product)
    variant.archive_content!(revision: variant.draft_revision)
    product.archive_content!(revision: product.reload.draft_revision)
    refute policy.can_archive?(product)
    refute policy.can_archive_variant?(product, variant)
    assert policy.can_restore?(product)
    refute policy.can_copy?(product)
    assert policy.can_restore_variant?(product, variant)
    refute policy.can_restore_variant?(other, variant)
    membership.update!(role: :viewer)
    refute policy.can_restore?(product)
    refute policy.can_restore_variant?(product, variant)
  end

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
