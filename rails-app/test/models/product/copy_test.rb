require "test_helper"
require_relative "../../test_helpers/catalogue_test_helper"

class Product::CopyTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  setup do
    @category = Current.bucket.recordings.create!(recordable: Category.new(name: "Starters"))
    @allergen = Current.bucket.recordings.create!(recordable: Allergen.new(name: "Milk"))
    @source = create_catalogue_product(description: "Crispy", category_ids: [ @category.id ])
    @first = @source.children.variants.sole
    @first.revise_content!({ name: "Regular", price: "5.95", allergen_ids: [ @allergen.id ] }, revision: @first.draft_revision)
    @large = add_catalogue_variant(@source)
    @source.reload
  end

  test "copies independent draft content in order with image assignments and provenance but no publication or availability" do
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("image"), filename: "wings.png", content_type: "image/png", identify: false)
    draft = Product::Draft.for(@source)
    draft.image = blob
    assert draft.save
    Product::VariantChanges.new(@source.reload).reorder!([ @large.id, @first.id ], revision: @source.draft_revision)
    publication = Product::Publication.new(@source.reload)
    publication.publish!(token: publication.review_token)
    VariantAvailability.where(recording: [ @first, @large ]).update_all(available: true)
    original = @source.reload.recordable
    events = @source.timeline_events.count
    copy = build_copy
    assert_no_difference [ "Catalogue::Release.count", "Catalogue::Snapshot.count" ] do
      assert copy.save, copy.errors.full_messages.join(", ")
    end
    target = copy.recording.reload
    assert_equal "Wings copy", target.recordable.name
    assert_equal "Crispy", target.recordable.description
    assert_equal [ @category.id ], target.recordable.category_ids
    assert_equal blob, target.recordable.image.blob
    variants = Product::Draft.for(target).variants
    assert_equal %w[Large Regular], variants.map { |variant| variant.recordable.name }
    assert_equal [ BigDecimal("8.50"), BigDecimal("5.95") ], variants.map { |variant| variant.recordable.price }
    assert variants.all? { |variant| variant.recordable.allergen_ids == [ @allergen.id ] }
    assert_empty variants.map(&:id) & [ @first.id, @large.id ]
    refute VariantAvailability.where(recording: variants, available: true).exists?
    assert VariantAvailability.where(recording: [ @first, @large ], available: true).count == 2
    assert_equal original, @source.reload.recordable
    assert_equal events, @source.timeline_events.count
    refute target.catalogue_previously_published?
    [ target, *variants ].each do |recording|
      assert_equal Current.bucket, recording.bucket
      event = recording.events.find_by!(action: "copied")
      assert_equal Current.person, event.person
      assert event.details.find_by!(key: "source_recording_id").value.present?
    end
    variants.first.revise_content!({ name: "Independent", price: "9.00", allergen_ids: [] }, revision: variants.first.draft_revision)
    assert_equal "Large", @large.reload.recordable.name
  end

  test "archived variants and variants excluded from the draft order are not copied" do
    @large.archive_content!(revision: @large.reload.draft_revision)
    @source.children.create!(bucket: Current.bucket, recordable: Variant.new(name: "Not in draft", price: 1))
    copy = build_copy
    assert copy.save
    assert_equal [ "Regular" ], Product::Draft.for(copy.recording).variants.map { |variant| variant.recordable.name }
  end

  test "invalid name missing active variants and archived classifiers fail without partial copies" do
    copy = build_copy
    copy.name = ""
    assert_no_difference "Recording.count" do
      refute copy.save
    end
    @allergen.archive_content!(revision: @allergen.draft_revision)
    copy = build_copy
    refute copy.save
    assert_match /archived/, copy.errors.full_messages.join
    @allergen.restore_content!(revision: @allergen.reload.draft_revision)
    @category.archive_content!(revision: @category.draft_revision)
    refute build_copy.save
    [ @first, @large ].each { |variant| variant.archive_content!(revision: variant.reload.draft_revision) }
    copy = build_copy
    refute copy.save
    assert_match /Restore at least one variant/, copy.errors.full_messages.join
  end

  test "stale or archived source cannot be copied" do
    copy = build_copy
    @first.revise_content!({ name: "New name", price: 2, allergen_ids: [] }, revision: @first.reload.draft_revision)
    assert_raises(Recording::CatalogueEditing::StaleDraft) { copy.save }
    @source.archive_content!(revision: @source.reload.draft_revision)
    assert_raises(Authorization::Denied) { build_copy.save }
  end

  test "failed variant availability creation rolls back content events and permits retry" do
    copy = build_copy
    failure = ->(**attributes) { raise ActiveRecord::RecordInvalid.new(VariantAvailability.new) }
    assert_no_difference [ "Recording.count", "Product.count", "Variant.count", "Event.count", "VariantAvailability.count" ] do
      with_class_method_replacement(VariantAvailability, :create!, failure) { refute copy.save }
    end
    assert_nil copy.recording
    assert copy.save
    assert_equal 2, copy.recording.children.variants.count
  end

  private

  def build_copy
    Product::Copy.new(source: @source.reload, name: "Wings copy", revision: @source.draft_revision)
  end
end
