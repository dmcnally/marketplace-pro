require "test_helper"
require_relative "../../test_helpers/catalogue_test_helper"

class Catalogue::AllergenWarningsTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  setup do
    @milk = Current.bucket.recordings.create!(recordable: Allergen.new(name: "Milk", description: "Original wording"))
    @product = create_catalogue_product
    @variant = @product.children.variants.sole
    assign([ @milk.id ])
    publish_product
    @menu = create_catalogue_menu
    add_menu_section(@menu, product_ids: [ @product.id ])
    add_menu_section(@menu, name: "Sharing", product_ids: [ @product.id ])
    publish_menu
  end

  test "allergen wording changes warn once preserve published wording and require product republication" do
    assert_empty warnings.entries
    assert_equal [ @product.id ], warnings.affected_by(@milk).map { |product| product.recording.id }
    @milk.revise_content!({ name: "Dairy", description: "Revised wording" }, revision: @milk.draft_revision)
    entry = warnings.entries.sole
    assert_equal @product, entry[:recording]
    assert_equal "Milk: Original wording", entry[:changes].sole[:before]
    assert_equal "Dairy: Revised wording", entry[:changes].sole[:after]
    publication = Product::Publication.new(@product.reload)
    assert publication.changed?
    assert_equal "Milk", Catalogue::PublishedProduct.new(@product).variants.sole.fetch("allergens").sole.fetch("name")
    publish_menu
    assert_equal 1, warnings.entries.size
    publish_product
    assert_empty warnings.entries
    assert_equal "Dairy", Catalogue::PublishedProduct.new(@product).variants.sole.fetch("allergens").sole.fetch("name")
  end

  test "individual and bulk assignment changes warn and assignment reversion resolves them" do
    assign([])
    assert_equal "None", warnings.entries.sole[:changes].sole[:after]
    assert_equal [ @product.id ], warnings.affected_by(@milk).map { |product| product.recording.id }
    publication = Product::Publication.new(@product.reload)
    publication.revert!(token: publication.review_token)
    assert_empty warnings.entries
    gluten = Current.bucket.recordings.create!(recordable: Allergen.new(name: "Gluten"))
    Product::VariantChanges.new(@product.reload).assign_allergen!(gluten.id, remove: false, revision: @product.draft_revision)
    assert_match /Gluten/, warnings.entries.sole[:changes].sole[:after]
    publish_product
    assert_empty warnings.entries
  end

  test "price changes availability and allergen order alone do not warn" do
    gluten = Current.bucket.recordings.create!(recordable: Allergen.new(name: "Gluten"))
    assign([ @milk.id, gluten.id ])
    publish_product
    @variant.revise_content!({ name: "Changed name", price: 20, allergen_ids: [ gluten.id, @milk.id ] }, revision: @variant.reload.draft_revision)
    VariantAvailability.find_by!(recording: @variant).update!(available: true)
    assert Product::Publication.new(@product.reload).changed?
    assert_empty warnings.entries
  end

  test "archived variants products absent placements and foreign buckets do not warn" do
    assign([])
    assert_equal 1, warnings.entries.size
    assert_empty Catalogue::AllergenWarnings.new(Bucket.create!(name: "Other")).entries
    @variant.archive_content!(revision: @variant.reload.draft_revision)
    assert_empty warnings.entries
    @variant.restore_content!(revision: @variant.reload.draft_revision)
    assert_equal 1, warnings.entries.size
    @product.archive_content!(revision: @product.reload.draft_revision)
    assert_empty warnings.entries
    @product.restore_content!(revision: @product.reload.draft_revision)
    publication = Menu::Publication.new(@menu.reload)
    publication.unpublish!(token: publication.review_token)
    assert_empty warnings.entries
    assert_empty warnings.affected_by(@milk)
  end

  test "new draft variants with allergens warn without exposing them in the published version" do
    added = add_catalogue_variant(@product)
    assert_equal 1, Catalogue::PublishedProduct.new(@product).variants.size
    assert_equal added.recordable.name, warnings.entries.sole[:changes].sole[:variant_name]
    assert_equal "None", warnings.entries.sole[:changes].sole[:before]
    assert_no_difference "Event.count" do
      warnings.entries
      warnings.affected_by(@milk)
    end
  end

  private

  def warnings = Catalogue::AllergenWarnings.new(Current.bucket)

  def assign(ids)
    @variant.revise_content!({ name: "Regular", price: "5.95", allergen_ids: ids }, revision: @variant.reload.draft_revision)
  end

  def publish_product
    publication = Product::Publication.new(@product.reload)
    publication.publish!(token: publication.review_token)
  end

  def publish_menu
    publication = Menu::Publication.new(@menu.reload)
    publication.publish!(token: publication.review_token)
  end
end
