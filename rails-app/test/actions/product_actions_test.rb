require "test_helper"
require_relative "../test_helpers/catalogue_test_helper"

class ProductActionsTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  class View
    def new_admin_product_publication_path(recording) = "/admin/products/#{recording.id}/publication/new"
    def admin_product_publication_path(recording) = "/admin/products/#{recording.id}/publication"
    def new_admin_product_reversion_path(recording) = "/admin/products/#{recording.id}/reversion/new"
    def admin_product_reversion_path(recording) = "/admin/products/#{recording.id}/reversion"
    def link_to(label, path, **options) = { label: label, path: path, options: options }
    def button_to(label, path, **options) = { label: label, path: path, options: options }
  end

  test "publication controls honor permissions and state without mutating records" do
    product = create_catalogue_product
    publication = Product::Publication.new(product)
    actions = ProductActions.new(view: View.new, person: Current.person, bucket: Current.bucket)
    assert_nil actions.publication_link_for(product)
    assert_nil actions.publish_button_for(publication)
    assert_nil actions.revert_link_for(product)
    assert_nil actions.revert_button_for(publication)
    assert_nil actions.unpublish_button_for(publication)
    Membership.create!(person: Current.person, bucket: Current.bucket, role: :editor)
    assert_equal "Review publication", actions.publication_link_for(product)[:label]
    assert_no_difference [ "Catalogue::Snapshot.count", "Event.count" ] do
      assert_equal publication.review_token, actions.publish_button_for(publication)[:options][:params][:review_token]
    end
    assert_nil actions.revert_button_for(publication)
    publication.publish!(token: publication.review_token)
    assert_equal :delete, actions.unpublish_button_for(publication)[:options][:method]
    assert_equal "Revert all changes", actions.revert_link_for(product)[:label]
    assert_equal "Revert all", actions.revert_button_for(publication)[:label]
    product.children.variants.sole.tap { |variant| variant.archive_content!(revision: variant.draft_revision) }
    assert_nil actions.publish_button_for(publication)
  end
end
