require "test_helper"
require_relative "../../test_helpers/catalogue_test_helper"

class Catalogue::AvailabilityTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  setup do
    @actor = users(:two).person
    @membership = Membership.create!(person: @actor, bucket: Current.bucket, role: :viewer)
    @product = create_catalogue_product
    @regular = @product.children.variants.sole
    @large = add_catalogue_variant(@product)
    publication = Product::Publication.new(@product.reload)
    publication.publish!(token: publication.review_token)
    @menu = create_catalogue_menu
    add_menu_section(@menu, product_ids: [ @product.id ])
    add_menu_section(@menu, name: "Sharing", product_ids: [ @product.id ])
    publication = Menu::Publication.new(@menu.reload)
    publication.publish!(token: publication.review_token)
    @availability = Catalogue::Availability.new(bucket: Current.bucket, person: @actor)
  end

  test "viewer changes one live variant with attributed before after events and idempotent retries" do
    snapshots = Catalogue::Snapshot.order(:id).pluck(:id, :content)
    assert_difference "Event.count", 1 do
      @availability.set_variant!(@regular, available: true)
    end
    assert state(@regular).available?
    refute state(@large).available?
    event = @regular.events.find_by!(action: "availability_changed")
    assert_equal @actor, event.person
    assert_equal({ "from" => "unavailable", "to" => "available", "reason" => "Staff availability change" }, event.details.pluck(:key, :value).to_h)
    assert_no_difference "Event.count" do
      @availability.set_variant!(@regular, available: true)
    end
    @availability.set_variant!(@regular, available: false)
    refute state(@regular).available?
    assert_equal snapshots, Catalogue::Snapshot.order(:id).pluck(:id, :content)
    refute Product::Publication.new(@product.reload).changed?
  end

  test "bulk changes only published visible variants once across duplicate placements" do
    draft = add_catalogue_variant(@product, name: "Draft only")
    assert_difference "Event.count", 2 do
      @availability.set_product!(@product, available: true)
    end
    assert state(@regular).available?
    assert state(@large).available?
    refute state(draft).available?
    @large.archive_content!(revision: @large.reload.draft_revision)
    assert_difference "Event.count", 1 do
      @availability.set_product!(@product, available: false)
    end
    refute state(@regular).available?
    refute state(@large).available?
  end

  test "bulk failure rolls back earlier variants and their events" do
    original = VariantAvailability.method(:find_by!)
    failing_state = state(@large)
    failing_id = @large.id
    failing_state.define_singleton_method(:change!) { |**arguments| raise ActiveRecord::RecordInvalid.new(self) }
    replacement = ->(**attributes) { attributes[:recording_id] == failing_id ? failing_state : original.call(**attributes) }
    assert_no_difference "Event.count" do
      with_class_method_replacement(VariantAvailability, :find_by!, replacement) do
        assert_raises(ActiveRecord::RecordInvalid) { @availability.set_product!(@product, available: true) }
      end
    end
    refute state(@regular).available?
    refute state(@large).available?
  end

  test "stale objects cannot change archived or no longer live variants and revoked membership is checked again" do
    stale_variant = Recording.find(@regular.id)
    @regular.archive_content!(revision: @regular.reload.draft_revision)
    assert_raises(Authorization::Denied) { @availability.set_variant!(stale_variant, available: true) }
    @regular.restore_content!(revision: @regular.reload.draft_revision)
    @membership.destroy!
    assert_raises(Authorization::Denied) { @availability.set_variant!(stale_variant, available: true) }
    Membership.create!(person: @actor, bucket: Current.bucket, role: :viewer)
    publication = Menu::Publication.new(@menu.reload)
    publication.unpublish!(token: publication.review_token)
    assert_raises(Authorization::Denied) { @availability.set_variant!(stale_variant, available: true) }
    assert_raises(Authorization::Denied) { @availability.set_product!(@product, available: true) }
  end

  test "draft placement publication alone foreign records and invalid state are rejected without mutation" do
    outside = create_catalogue_product
    publication = Product::Publication.new(outside)
    publication.publish!(token: publication.review_token)
    add_menu_section(@menu, product_ids: [ outside.id ])
    foreign = create_catalogue_product(bucket: Bucket.create!(name: "Other"))
    assert_no_difference "Event.count" do
      [ outside, foreign ].each do |product|
        assert_raises(Authorization::Denied) { @availability.set_product!(product, available: true) }
        assert_raises(Authorization::Denied) { @availability.set_variant!(product.children.variants.sole, available: true) }
      end
      [ nil, "true", 1 ].each do |value|
        assert_raises(ArgumentError) { @availability.set_variant!(@regular, available: value) }
      end
    end
  end

  private

  def state(variant) = VariantAvailability.find_by!(recording: variant)
end
