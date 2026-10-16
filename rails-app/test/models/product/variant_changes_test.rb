require "test_helper"
require_relative "../../test_helpers/catalogue_test_helper"

class Product::VariantChangesTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  setup do
    @product = create_catalogue_product
    @first = @product.children.variants.sole
    @second = add_catalogue_variant(@product)
    @product.reload
    @allergen = Current.bucket.recordings.create!(recordable: Allergen.new(name: "Milk"))
    @changes = Product::VariantChanges.new(@product)
  end

  test "ordering requires an exact permutation and records an immutable version" do
    original = @product.recordable
    [ [ @first.id ], [ @first.id, @first.id ], [ @first.id, -1 ] ].each do |ids|
      assert_no_difference [ "Product.count", "Event.count" ] do
        assert_raises(ArgumentError) { @changes.reorder!(ids, revision: @product.draft_revision) }
      end
    end
    @changes.reorder!([ @second.id, @first.id ], revision: @product.draft_revision)
    assert_equal [ @second.id, @first.id ], @product.reload.recordable.variant_order
    assert_equal [ @first.id, @second.id ], original.reload.variant_order
    assert_equal original, @product.events.order(:id).last.subject_previous
  end

  test "bulk changes create one attributed change per affected variant and no duplicate no-op events" do
    originals = [ @first.recordable, @second.recordable ]
    assert_difference "Event.count", 2 do
      @changes.assign_allergen!(@allergen.id, remove: false, revision: @product.draft_revision)
    end
    [ @first, @second ].each_with_index do |variant, index|
      assert_equal [ @allergen.id ], variant.reload.recordable.allergen_ids
      event = variant.events.order(:id).last
      assert_equal originals[index], event.subject_previous
      assert_equal Current.person, event.person
    end
    assert_no_difference "Event.count" do
      @changes.assign_allergen!(@allergen.id, remove: false, revision: @product.reload.draft_revision)
    end
    @allergen.archive_content!(revision: @allergen.draft_revision)
    @changes.assign_allergen!(@allergen.id, remove: true, revision: @product.reload.draft_revision)
    assert_empty @first.reload.recordable.allergen_ids
    assert_empty @second.reload.recordable.allergen_ids
  end

  test "foreign or archived allergens cannot be bulk assigned and stale commands make no changes" do
    foreign = Bucket.create!(name: "Other allergens").recordings.create!(recordable: Allergen.new(name: "Other"))
    @allergen.archive_content!(revision: @allergen.draft_revision)
    [ foreign.id, @allergen.id ].each do |id|
      assert_raises(ActiveRecord::RecordNotFound) { @changes.assign_allergen!(id, remove: false, revision: @product.draft_revision) }
    end
    assert_raises(Recording::CatalogueEditing::StaleDraft) { @changes.assign_allergen!(@allergen.id, remove: true, revision: "old") }
    assert_empty @first.reload.recordable.allergen_ids
  end

  test "bulk changes skip archived variants" do
    @second.archive_content!(revision: @second.draft_revision)
    @changes.assign_allergen!(@allergen.id, remove: false, revision: @product.reload.draft_revision)
    assert_equal [ @allergen.id ], @first.reload.recordable.allergen_ids
    assert_empty @second.reload.recordable.allergen_ids
  end

  test "a failure on the second variant rolls back earlier edits and their events" do
    builder = Variant.method(:new)
    count = 0
    fail_second = lambda do |attributes|
      count += 1
      builder.call(attributes.merge(count == 2 ? { "name" => "" } : {}))
    end
    assert_no_difference [ "Variant.count", "Event.count" ] do
      with_class_method_replacement(Variant, :new, fail_second) do
        assert_raises(ActiveRecord::RecordInvalid) { @changes.assign_allergen!(@allergen.id, remove: false, revision: @product.draft_revision) }
      end
    end
    assert_empty @first.reload.recordable.allergen_ids
    assert_empty @second.reload.recordable.allergen_ids
  end
end
