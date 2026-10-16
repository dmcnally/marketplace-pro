require "test_helper"
require_relative "../../test_helpers/catalogue_test_helper"

class Product::PublicationTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  setup do
    @product = create_catalogue_product
    @variant = @product.children.variants.sole
    @allergen = Current.bucket.recordings.create!(recordable: Allergen.new(name: "Milk", description: "Milk products"))
    draft = Product::VariantDraft.for(@product, @variant)
    draft.allergen_ids = [ @allergen.id ]
    assert draft.save
    @product.reload
    @publication = Product::Publication.new(@product)
  end

  test "publication snapshots product variants prices and allergen wording without enabling sales" do
    @publication.publish!(token: @publication.review_token)
    assert @publication.published?
    refute @publication.changed?
    snapshot = @publication.release.snapshot
    assert_equal "Wings", snapshot.content["name"]
    assert_equal "5.95", snapshot.content.fetch("variants").sole.fetch("price")
    assert_equal "Milk products", snapshot.content.fetch("variants").sole.fetch("allergens").sole.fetch("description")
    refute VariantAvailability.find_by!(recording: @variant).available?
    event = @product.events.where(action: "published").sole
    assert_equal Current.person, event.person
    assert_equal snapshot.id.to_s, event.details.find_by!(key: "snapshot_id").value
    @allergen.revise_content!({ name: "Milk", description: "Updated wording" }, revision: @allergen.draft_revision)
    assert @publication.changed?
    assert_equal "Milk products", snapshot.reload.content.fetch("variants").sole.fetch("allergens").sole.fetch("description")
    @publication.publish!(token: @publication.review_token)
    assert_equal 2, Catalogue::Snapshot.where(recording: @product).count
    assert_equal "Updated wording", @publication.previous_content.fetch("variants").sole.fetch("allergens").sole.fetch("description")
  end

  test "review becomes stale after allergen edits or variant edits and cannot be replayed" do
    token = @publication.review_token
    @allergen.revise_content!({ name: "Milk updated" }, revision: @allergen.draft_revision)
    assert_no_difference [ "Catalogue::Snapshot.count", "Catalogue::Release.count" ] do
      assert_raises(Recording::CatalogueEditing::StaleDraft) { @publication.publish!(token: token) }
    end
    token = @publication.review_token
    edit = Product::VariantDraft.for(@product, @variant)
    edit.price = "6"
    assert edit.save
    assert_raises(Recording::CatalogueEditing::StaleDraft) { @publication.publish!(token: token) }
    fresh = @publication.review_token
    @publication.publish!(token: fresh)
    assert_raises(Recording::CatalogueEditing::StaleDraft) { @publication.publish!(token: fresh) }
  end

  test "no active variants or an archived product cannot publish" do
    @variant.archive_content!(revision: @variant.draft_revision)
    @product.reload
    assert_no_difference [ "Catalogue::Snapshot.count", "Catalogue::Release.count" ] do
      assert_raises(Product::Publication::Invalid) { @publication.publish!(token: @publication.review_token) }
    end
    @variant.restore_content!(revision: @variant.draft_revision)
    @product.reload.archive_content!(revision: @product.draft_revision)
    assert_raises(Product::Publication::Invalid) { @publication.publish!(token: @publication.review_token) }
  end

  test "unpublish keeps latest snapshot and reverting does not republish or change availability" do
    @publication.publish!(token: @publication.review_token)
    snapshot = @publication.release.snapshot
    @publication.unpublish!(token: @publication.review_token)
    refute @publication.published?
    assert_equal snapshot, @publication.release.snapshot
    edit = Product::VariantDraft.for(@product.reload, @variant.reload)
    edit.price = "8"
    edit.allergen_ids = []
    assert edit.save
    extra = add_catalogue_variant(@product)
    availability = VariantAvailability.find_by!(recording: @variant)
    availability.update!(available: true)
    @publication.revert!(token: @publication.review_token)
    refute @publication.published?
    assert_equal snapshot, @publication.release.snapshot
    assert_equal BigDecimal("5.95"), @variant.reload.recordable.price
    assert_equal [ @allergen.id ], @variant.recordable.allergen_ids
    assert availability.reload.available?
    assert_equal [ @variant.id ], Product::Draft.for(@product.reload).variants.map(&:id)
    assert extra.reload.kept?, "Reverting must not archive a variant"
    assert extra.events.exists?, "Draft-only variant history must be retained"
    assert_equal 1, @product.events.where(action: "reverted").count
  end

  test "revert preserves archived references and reports them" do
    @publication.publish!(token: @publication.review_token)
    @variant.archive_content!(revision: @variant.draft_revision)
    @allergen.archive_content!(revision: @allergen.draft_revision)
    @product.reload
    @publication.revert!(token: @publication.review_token)
    assert @variant.reload.discarded?
    assert @allergen.reload.discarded?
    refute VariantAvailability.find_by!(recording: @variant).available?
    assert_includes @publication.archived_references, "Default"
    assert_includes @publication.archived_references, "Milk"
  end

  test "never published products cannot revert and wrong recordable types are rejected" do
    assert_raises(Product::Publication::Invalid) { @publication.revert!(token: @publication.review_token) }
    assert_raises(ArgumentError) { Product::Publication.new(@allergen) }
  end

  test "impact comparison includes removed variants and changes to allergen wording" do
    @publication.publish!(token: @publication.review_token)
    assert_empty @publication.variant_changes
    @allergen.revise_content!({ name: "Milk", description: "New wording" }, revision: @allergen.draft_revision)
    change = @publication.variant_changes.sole
    assert_equal "Milk: Milk products", change[:before_allergens]
    assert_equal "Milk: New wording", change[:after_allergens]
    @variant.archive_content!(revision: @variant.draft_revision)
    assert_nil @publication.variant_changes.sole[:after_price]
  end

  test "a referenced live menu prevents unpublishing until its release is withdrawn" do
    @publication.publish!(token: @publication.review_token)
    menu = Struct.new(:snapshot_id) do
      def includes_product?(_product) = true
    end.new(123)
    with_class_method_replacement(Catalogue::Release, :live_menu, ->(_bucket) { menu }) do
      assert_equal menu, @publication.live_menu
      assert_no_difference "Event.count" do
        assert_raises(Product::Publication::Invalid) { @publication.unpublish!(token: @publication.review_token) }
      end
      assert @publication.published?
    end
    @publication.unpublish!(token: @publication.review_token)
    refute @publication.published?
  end

  test "failed release creation rolls back the snapshot and permits retry" do
    invalid_release = Catalogue::Release.new
    failure = ->(**) { raise ActiveRecord::RecordInvalid.new(invalid_release) }
    assert_no_difference [ "Catalogue::Snapshot.count", "Catalogue::Release.count", "Event.count" ] do
      with_class_method_replacement(Catalogue::Release, :new, failure) do
        assert_raises(ActiveRecord::RecordInvalid) { @publication.publish!(token: @publication.review_token) }
      end
    end
    @publication.publish!(token: @publication.review_token)
    assert @publication.published?
  end
end
