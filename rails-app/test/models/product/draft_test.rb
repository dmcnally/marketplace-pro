require "test_helper"
require_relative "../../test_helpers/catalogue_test_helper"

class Product::DraftTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  test "creation owns a default variant and unavailable state in the same bucket" do
    product = create_catalogue_product(price: "0")
    variant = product.children.variants.sole
    assert_equal Current.bucket, variant.bucket
    assert_equal [ variant.id ], product.recordable.variant_order
    assert_equal "Default", variant.recordable.name
    assert_equal 0, variant.recordable.price
    assert_empty variant.recordable.allergen_ids
    refute VariantAvailability.find_by!(recording: variant).available?
    assert_equal Current.person, variant.events.sole.person
  end

  test "invalid initial variant rolls back product content recordings state and events" do
    draft = Product::Draft.new(bucket: Current.bucket, name: "Wings", price: "-1")
    assert_no_difference [ "Product.count", "Variant.count", "Recording.count", "VariantAvailability.count", "Event.count" ] do
      refute draft.save
    end
    assert draft.errors[:price].any?
    assert_nil draft.recording
  end

  test "editing replaces content preserves image and leaves availability alone" do
    product = create_catalogue_product(image: Rack::Test::UploadedFile.new(Rails.root.join("public/icon.png"), "image/png"))
    original = product.recordable
    availability = VariantAvailability.find_by!(recording: product.children.variants.sole)
    availability.update!(available: true)
    draft = Product::Draft.for(product)
    draft.name = "Hot wings"
    assert draft.save
    assert_equal "Wings", original.reload.name
    assert_equal "Hot wings", product.reload.recordable.name
    assert_equal original.image.blob, product.recordable.image.blob
    assert availability.reload.available?
    assert_equal original, product.events.where(action: "updated").order(:id).last.subject_previous
    draft = Product::Draft.for(product)
    draft.remove_image = "1"
    assert draft.save
    refute product.reload.recordable.image.attached?
    assert original.reload.image.attached?
  end

  test "failure after creating content rolls back the entire aggregate and permits retry" do
    draft = Product::Draft.new(bucket: Current.bucket, name: "Wings", price: "1")
    failure = ->(**) { raise ActiveRecord::RecordInvalid.new(VariantAvailability.new) }
    assert_no_difference [ "Product.count", "Variant.count", "Recording.count", "VariantAvailability.count", "Event.count" ] do
      with_class_method_replacement(VariantAvailability, :create!, failure) { refute draft.save }
    end
    assert_nil draft.recording
    assert draft.save
    assert draft.recording.persisted?
    assert_equal 1, draft.recording.children.variants.count
  end

  test "rejects foreign or newly archived categories but preserves existing retired assignments" do
    category = Current.bucket.recordings.create!(recordable: Category.new(name: "Starters"))
    product = create_catalogue_product(category_ids: [ category.id ])
    category.archive_content!(revision: category.draft_revision)
    draft = Product::Draft.for(product)
    draft.name = "Changed"
    assert draft.save
    assert_equal [ category.id ], product.reload.recordable.category_ids
    foreign = Bucket.create!(name: "Other").recordings.create!(recordable: Category.new(name: "Foreign"))
    [ category.id, foreign.id, -1 ].each do |id|
      invalid = Product::Draft.new(bucket: Current.bucket, name: "No", price: "1", category_ids: [ id ])
      assert_no_difference "Product.count" do
        refute invalid.save
      end
      assert invalid.errors[:category_ids].any?
    end
  end

  test "rejects cross-bucket draft context before changing content" do
    product = create_catalogue_product
    draft = Product::Draft.for(product)
    draft.bucket = Bucket.create!(name: "Wrong owner")
    draft.name = "Wrong"
    refute draft.save
    assert_equal "Wings", product.reload.recordable.name
  end

  test "stale drafts and archived products cannot be edited" do
    product = create_catalogue_product
    stale = Product::Draft.for(product)
    latest = Product::Draft.for(Current.bucket.recordings.find(product.id))
    latest.name = "Latest"
    assert latest.save
    stale.name = "Stale"
    assert_raises(Recording::CatalogueEditing::StaleDraft) { stale.save }
    product.reload.archive_content!(revision: product.draft_revision)
    archived = Product::Draft.for(product.reload)
    archived.name = "Archived edit"
    assert_raises(Authorization::Denied) { archived.save }
  end
end
