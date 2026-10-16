require "test_helper"
require_relative "../../test_helpers/catalogue_test_helper"

class Product::CatalogueTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  setup do
    @category = Current.bucket.recordings.create!(recordable: Category.new(name: "Starters"))
    @draft = create_catalogue_product(name: "Lemonade")
    @published = create_catalogue_product(name: "Wings", category_ids: [ @category.id ])
    publication = Product::Publication.new(@published)
    publication.publish!(token: publication.review_token)
  end

  test "publication filters distinguish never published withdrawn and changed content" do
    assert_equal [ @draft.id ], ids(publication_state: "never_published")
    assert_equal [ @published.id ], ids(publication_state: "published")
    assert_empty ids(publication_state: "unpublished")
    assert_empty ids(publication_state: "changed")
    draft = Product::Draft.for(@published.reload)
    draft.description = "Changed"
    assert draft.save
    assert_equal [ @published.id ], ids(publication_state: "changed")
    assert_match /Published · Unpublished changes/, catalogue(publication_state: "published").rows.sole[:status]
    publication = Product::Publication.new(@published.reload)
    publication.unpublish!(token: publication.review_token)
    assert_equal [ @published.id ], ids(publication_state: "unpublished")
    assert_equal [ @published.id ], ids(publication_state: "changed")
    assert_empty ids(publication_state: "published")
  end

  test "search and category filters combine literally and preserve archived assignments" do
    assert_equal [ @published.id ], ids(query: "  wiNG  ", category_id: @category.id, publication_state: "published")
    assert_empty ids(query: "Lemon", category_id: @category.id)
    assert_empty ids(query: "%")
    literal = create_catalogue_product(name: "100% juice")
    assert_equal [ literal.id ], ids(query: "%")
    @category.archive_content!(revision: @category.draft_revision)
    assert_equal [ @published.id ], ids(category_id: @category.id)
    assert_includes catalogue.categories, @category
  end

  test "foreign and invalid filters cannot leak data or silently broaden results" do
    bucket = Bucket.create!(name: "Other")
    foreign_category = bucket.recordings.create!(recordable: Category.new(name: "Foreign"))
    create_catalogue_product(bucket: bucket, name: "Foreign product")
    assert_equal [ @draft.id, @published.id ], ids
    [ foreign_category.id, "invalid", "#{@category.id}junk" ].each do |id|
      assert catalogue(category_id: id).invalid_filter?
      assert_empty ids(category_id: id)
    end
    assert catalogue(publication_state: "unknown").invalid_filter?
    assert_empty ids(publication_state: "unknown")
    @published.archive_content!(revision: @published.reload.draft_revision)
    assert_equal [ @draft.id ], ids
  end

  test "row prices and counts include only active variants in draft order" do
    extra = add_catalogue_variant(@published, price: "1.25")
    @published.children.create!(bucket: Current.bucket, recordable: Variant.new(name: "Excluded", price: "0.01"))
    row = catalogue(category_id: @category.id).rows.sole
    assert_equal 2, row[:variant_count]
    assert_equal BigDecimal("1.25"), row[:minimum_price]
    extra.archive_content!(revision: extra.reload.draft_revision)
    row = catalogue(category_id: @category.id).rows.sole
    assert_equal 1, row[:variant_count]
    assert_equal BigDecimal("5.95"), row[:minimum_price]
    original = @published.children.variants.find(@published.reload.recordable.variant_order.first)
    original.archive_content!(revision: original.reload.draft_revision)
    row = catalogue(category_id: @category.id).rows.sole
    assert_equal 0, row[:variant_count]
    assert_nil row[:minimum_price]
  end

  private

  def catalogue(**options) = Product::Catalogue.new(bucket: Current.bucket, **options)
  def ids(**options) = catalogue(**options).rows.map { |row| row[:recording].id }
end
