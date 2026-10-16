require "test_helper"
require_relative "../test_helpers/catalogue_test_helper"

class AvailabilityActionsTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  class View
    def availability_path = "/availability"
    def button_to(label, path, **options) = { label: label, path: path, options: options }
    def safe_join(items) = items
  end

  test "controls use explicit target states and are hidden without live eligibility" do
    product = create_catalogue_product
    add_catalogue_variant(product)
    publication = Product::Publication.new(product.reload)
    publication.publish!(token: publication.review_token)
    menu = create_catalogue_menu
    add_menu_section(menu, product_ids: [ product.id ])
    publication = Menu::Publication.new(menu.reload)
    publication.publish!(token: publication.review_token)
    row = Catalogue::Overview.new(Current.bucket).products.sole
    actions = AvailabilityActions.new(view: View.new, person: Current.person, bucket: Current.bucket)
    assert_nil actions.variant_button_for(row[:variants].first)
    assert_nil actions.product_buttons_for(row)
    Membership.create!(person: Current.person, bucket: Current.bucket, role: :viewer)
    assert_no_difference "Event.count" do
      assert_equal :post, actions.variant_button_for(row[:variants].first)[:options][:method]
      assert_equal :delete, actions.variant_button_for(row[:variants].first.merge(available: true))[:options][:method]
      assert_equal [ :post, :delete ], actions.product_buttons_for(row).map { |button| button[:options][:method] }
    end
    menu.archive_content!(revision: menu.reload.draft_revision)
    assert_nil actions.variant_button_for(row[:variants].first)
    assert_nil actions.product_buttons_for(row)
  end
end
