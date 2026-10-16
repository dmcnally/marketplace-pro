require "test_helper"
require_relative "../../test_helpers/catalogue_test_helper"

class Product::VariantDraftTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  setup do
    @product = create_catalogue_product
    @variant = @product.children.variants.sole
    @allergen = Current.bucket.recordings.create!(recordable: Allergen.new(name: "Milk"))
  end

  test "copying preserves allergens but never copies live availability" do
    edit = Product::VariantDraft.for(@product, @variant)
    edit.allergen_ids = [ @allergen.id ]
    assert edit.save
    VariantAvailability.find_by!(recording: @variant).update!(available: true)
    copy = add_catalogue_variant(@product)
    assert_equal [ @allergen.id ], copy.recordable.allergen_ids
    refute VariantAvailability.find_by!(recording: copy).available?
    assert_equal [ @variant.id, copy.id ], @product.reload.recordable.variant_order
    change = Product::VariantDraft.for(@product, copy)
    change.allergen_ids = []
    assert change.save
    assert_empty copy.reload.recordable.allergen_ids
    assert_equal [ @allergen.id ], @variant.reload.recordable.allergen_ids
  end

  test "rejects absent foreign and archived copy sources without creating content" do
    foreign = create_catalogue_product.children.variants.sole
    [ nil, foreign.id ].each do |id|
      draft = Product::VariantDraft.new(product: @product, revision: @product.draft_revision, name: "Copy", price: "1", source_id: id)
      assert_no_difference [ "Variant.count", "Recording.count", "Event.count" ] do
        refute draft.save
      end
      assert draft.errors[:source_id].any?
    end
    @variant.archive_content!(revision: @variant.draft_revision)
    draft = Product::VariantDraft.new(product: @product.reload, revision: @product.draft_revision, name: "Copy", price: "1", source_id: @variant.id)
    refute draft.save
  end

  test "rejects editing a variant belonging to a different product" do
    foreign = create_catalogue_product.children.variants.sole
    draft = Product::VariantDraft.for(@product, foreign)
    draft.name = "Wrong product"
    refute draft.save
    assert_equal "Default", foreign.reload.recordable.name
  end

  test "new foreign and retired assignments fail while existing retired assignments can be kept or removed" do
    edit = Product::VariantDraft.for(@product, @variant)
    edit.allergen_ids = [ @allergen.id ]
    assert edit.save
    @allergen.archive_content!(revision: @allergen.draft_revision)
    edit = Product::VariantDraft.for(@product.reload, @variant.reload)
    edit.price = "7"
    assert edit.save
    assert_equal [ @allergen.id ], @variant.reload.recordable.allergen_ids
    edit = Product::VariantDraft.for(@product.reload, @variant)
    edit.allergen_ids = []
    assert edit.save
    foreign = Bucket.create!(name: "Foreign allergens").recordings.create!(recordable: Allergen.new(name: "Foreign"))
    [ @allergen.id, foreign.id ].each do |id|
      edit = Product::VariantDraft.for(@product.reload, @variant.reload)
      edit.allergen_ids = [ id ]
      refute edit.save
      assert edit.errors[:allergen_ids].any?
    end
  end

  test "invalid price and stale edits preserve the variant and its history" do
    original = @variant.recordable
    edit = Product::VariantDraft.for(@product, @variant)
    edit.price = "-1"
    assert_no_difference [ "Variant.count", "Event.count" ] do
      refute edit.save
    end
    stale = Product::VariantDraft.for(@product, @variant)
    fresh = Product::VariantDraft.for(@product, @variant)
    fresh.price = "7"
    assert fresh.save
    assert_raises(Recording::CatalogueEditing::StaleDraft) { stale.save }
    assert_equal BigDecimal("5.95"), original.reload.price
    assert_equal BigDecimal("7"), @variant.reload.recordable.price
  end

  test "failed operational state creation rolls back copied variant and supports retry" do
    draft = Product::VariantDraft.new(product: @product, revision: @product.draft_revision, name: "Copy", price: "1", source_id: @variant.id)
    order = @product.recordable.variant_order
    failure = ->(**) { raise ActiveRecord::RecordInvalid.new(VariantAvailability.new) }
    assert_no_difference [ "Product.count", "Variant.count", "Recording.count", "VariantAvailability.count", "Event.count" ] do
      with_class_method_replacement(VariantAvailability, :create!, failure) { refute draft.save }
    end
    assert_nil draft.recording
    assert_equal order, @product.reload.recordable.variant_order
    assert draft.save
    assert draft.recording.persisted?
    refute VariantAvailability.find_by!(recording: draft.recording).available?
  end
end
