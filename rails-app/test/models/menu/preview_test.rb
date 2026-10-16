require "test_helper"
require_relative "../../test_helpers/catalogue_test_helper"

class Menu::PreviewTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  test "draft structure combines published product content and explicit unpublished blockers" do
    menu = create_catalogue_menu
    product = create_catalogue_product(image: Rack::Test::UploadedFile.new(Rails.root.join("public/icon.png"), "image/png"))
    publication = Product::Publication.new(product)
    publication.publish!(token: publication.review_token)
    image = product.recordable.image.blob
    product.revise_content!(product.recordable.attributes.except("id").merge("name" => "Hidden draft"), revision: product.draft_revision)
    unpublished = create_catalogue_product(name: "Lemonade")
    first = add_menu_section(menu, product_ids: [ product.id, unpublished.id ])
    add_menu_section(menu, name: "Empty")
    preview = Menu::Preview.new(menu.reload)
    assert_no_difference [ "Catalogue::Snapshot.count", "Event.count" ] do
      assert_equal [ first ], preview.sections.map { |section| section[:recording] }
      assert_equal [ "Wings", "Lemonade" ], preview.sections.sole[:products].map(&:name)
      assert_equal [ unpublished ], preview.blockers
      assert_equal image, preview.sections.sole[:products].first.image
      assert_equal "5.95", preview.sections.sole[:products].first.variants.sole.fetch("price")
    end
  end

  test "archived variants and empty visible sections disappear but sold out variants remain" do
    menu = create_catalogue_menu
    product = create_catalogue_product
    variant = product.children.variants.sole
    publication = Product::Publication.new(product)
    publication.publish!(token: publication.review_token)
    add_menu_section(menu, product_ids: [ product.id ])
    preview = Menu::Preview.new(menu.reload)
    assert_equal "Sold out", preview.sections.sole[:products].sole.availability_for(preview.sections.sole[:products].sole.variants.sole)
    variant.archive_content!(revision: variant.draft_revision)
    assert_empty Menu::Preview.new(menu).sections
    variant.restore_content!(revision: variant.draft_revision)
    assert_equal 1, Menu::Preview.new(menu).sections.size
    product.reload.archive_content!(revision: product.draft_revision)
    assert_empty Menu::Preview.new(menu).sections
  end
end
