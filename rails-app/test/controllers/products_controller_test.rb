require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @bucket = Current.bucket
    @membership = Membership.create!(person: users(:two).person, bucket: @bucket, role: :editor)
    sign_in_as users(:two)
    @category = @bucket.recordings.create!(recordable: Category.new(name: "Starters"))
    @allergen = @bucket.recordings.create!(recordable: Allergen.new(name: "Milk"))
  end

  test "create product with default variant and zero price then edit immutable content" do
    get new_admin_product_path
    assert_response :success
    assert_difference -> { @bucket.recordings.products.count }, 1 do
      post admin_products_path, params: { product: { name: "Wings", price: "0.00", category_ids: [ @category.id ] } }
    end
    product = @bucket.recordings.products.last
    assert_redirected_to edit_admin_product_path(product)
    variant = product.children.variants.sole
    assert_equal "Default", variant.recordable.name
    assert_equal 0, variant.recordable.price
    assert_empty variant.recordable.allergen_ids
    refute VariantAvailability.find_by!(recording: variant).available?
    original = product.recordable
    get edit_admin_product_path(product)
    assert_response :success
    assert_select "h1", "Wings"
    patch admin_product_path(product), params: { revision: product.reload.draft_revision, product: { name: "Hot wings", category_ids: [ @category.id ] } }
    assert_response :see_other
    assert_equal "Wings", original.reload.name
    assert_equal "Hot wings", product.reload.recordable.name
    get admin_product_path(product)
    assert_response :success
    assert_select "ins", text: "Hot wings"
    get admin_products_path(q: "Hot")
    assert_response :success
    assert_select "strong", text: "Hot wings"
  end

  test "invalid first variant rolls back the whole product and keeps form values" do
    assert_no_difference [ "Product.count", "Variant.count", "Recording.count", "Event.count" ] do
      post admin_products_path, params: { product: { name: "Keep me", price: "-1" } }
    end
    assert_response :unprocessable_entity
    assert_select "input[name='product[name]'][value='Keep me']"
    assert_select "[role=alert]"
  end

  test "catalogue combines filters retains selections and reports prices publication and invalid filters" do
    product = create_product(category_ids: [ @category.id ])
    publication = Product::Publication.new(product)
    publication.publish!(token: publication.review_token)
    get admin_products_path(q: "Wings", category_id: @category.id, publication_state: "published")
    assert_response :success
    assert_select "input[name=q][value=Wings]"
    assert_select "select[name=category_id] option[selected][value=?]", @category.id.to_s
    assert_select "select[name=publication_state] option[selected][value=published]"
    assert_select ".catalogue__record p", "1 variant · 5.95 GBP · Published"
    assert_select "a[href=?]", admin_products_path, text: "Clear filters"
    get admin_products_path(publication_state: "never_published")
    assert_select ".catalogue__record", count: 0
    assert_select "p", /No products found/
    get admin_products_path(category_id: "invalid")
    assert_select "[role=alert]", /selected filter is unavailable/
    assert_select ".catalogue__record", count: 0
  end

  test "image edits preserve earlier versions and allow removing the draft image" do
    upload = Rack::Test::UploadedFile.new(Rails.root.join("public/icon.png"), "image/png")
    post admin_products_path, params: { product: { name: "Illustrated", price: "1", image: upload } }
    assert_response :redirect
    product = @bucket.recordings.products.last
    old_content = product.recordable
    assert old_content.image.attached?
    patch admin_product_path(product), params: { revision: product.draft_revision, product: { name: "Still illustrated" } }
    assert_response :see_other
    assert_equal old_content.image.blob, product.reload.recordable.image.blob
    patch admin_product_path(product), params: { revision: product.draft_revision, product: { name: "No image", remove_image: "1" } }
    assert_response :see_other
    refute product.reload.recordable.image.attached?
    assert old_content.reload.image.attached?
  end

  test "variant copying bulk allergens independent edits ordering and history" do
    product = create_product
    original = product.children.variants.sole
    patch admin_product_variant_path(product, original), params: { revision: product.draft_revision, variant: { name: "Regular", price: "5.95", allergen_ids: [ @allergen.id ] } }
    assert_response :see_other
    get new_admin_product_variant_path(product)
    assert_response :success
    post admin_product_variants_path(product), params: { revision: product.reload.draft_revision, variant: { name: "Large", price: "8.50", source_id: original.id } }
    assert_response :see_other
    copy = product.children.variants.order(:id).last
    assert_equal [ @allergen.id ], copy.recordable.allergen_ids
    refute VariantAvailability.find_by!(recording: copy).available?
    patch admin_product_variant_path(product, copy), params: { revision: product.reload.draft_revision, variant: { name: "Large", price: "9.00", allergen_ids: [ "" ] } }
    assert_response :see_other
    assert_empty copy.reload.recordable.allergen_ids
    assert_equal [ @allergen.id ], original.reload.recordable.allergen_ids
    post admin_product_allergen_assignment_path(product), params: { revision: product.reload.draft_revision, allergen_id: @allergen.id, operation: "assign" }
    assert_response :see_other
    assert_equal [ @allergen.id ], copy.reload.recordable.allergen_ids
    post admin_product_variant_order_path(product), params: { revision: product.reload.draft_revision, positions: { original.id => 2, copy.id => 1 } }
    assert_response :see_other
    assert_equal [ copy.id, original.id ], product.reload.recordable.variant_order
    get admin_product_path(product)
    assert_response :success
    assert_select "ins", text: /9.0/
    assert copy.events.where(action: "updated").exists?
  end

  test "archived and foreign classifiers cannot be newly assigned but existing archived assignments survive edits" do
    product = create_product(category_ids: [ @category.id ])
    @category.archive_content!(revision: @category.draft_revision)
    patch admin_product_path(product), params: { revision: product.draft_revision, product: { name: "Changed", category_ids: [ @category.id ] } }
    assert_response :see_other
    foreign = Bucket.create!(name: "Elsewhere").recordings.create!(recordable: Category.new(name: "Foreign"))
    [ foreign, @category ].each do |category|
      assert_no_difference "Product.count" do
        post admin_products_path, params: { product: { name: "Invalid", price: "1", category_ids: [ category.id ] } }
      end
      assert_response :unprocessable_entity
    end
    @allergen.archive_content!(revision: @allergen.draft_revision)
    variant = product.children.variants.sole
    patch admin_product_variant_path(product, variant), params: { revision: product.reload.draft_revision, variant: { name: "Default", price: "1", allergen_ids: [ @allergen.id ] } }
    assert_response :unprocessable_entity
    assert_empty variant.reload.recordable.allergen_ids
  end

  test "stale product and variant requests cannot replace a newer draft" do
    product = create_product
    revision = product.draft_revision
    patch admin_product_path(product), params: { revision: revision, product: { name: "Newest" } }
    assert_response :see_other
    patch admin_product_path(product), params: { revision: revision, product: { name: "Stale" } }
    assert_response :conflict
    post admin_product_variants_path(product), params: { revision: revision, variant: { name: "Stale variant", price: "2", source_id: product.children.variants.sole.id } }
    assert_response :conflict
    assert_equal "Newest", product.reload.recordable.name
    assert_equal 1, product.children.variants.count
  end

  test "viewers cannot access products or any variant operation" do
    product = create_product
    variant = product.children.variants.sole
    @membership.update!(role: :viewer)
    get admin_products_path
    assert_response :forbidden
    get admin_product_path(product)
    assert_response :forbidden
    get recording_diff_path(product)
    assert_response :forbidden
    assert_no_difference [ "Product.count", "Variant.count" ] do
      post admin_products_path, params: { product: { name: "Forbidden", price: "1" } }
      assert_response :forbidden
      patch admin_product_path(product), params: { revision: product.draft_revision, product: { name: "Forbidden" } }
      assert_response :forbidden
      patch admin_product_variant_path(product, variant), params: { revision: product.draft_revision, variant: { name: "Forbidden", price: "1" } }
      assert_response :forbidden
      post admin_product_allergen_assignment_path(product), params: { revision: product.draft_revision, allergen_id: @allergen.id }
      assert_response :forbidden
      post admin_product_variant_order_path(product), params: { revision: product.draft_revision, positions: { variant.id => 1 } }
      assert_response :forbidden
    end
  end

  test "variants must belong to the product in the route" do
    product = create_product
    other = create_product
    foreign_variant = other.children.variants.sole
    get edit_admin_product_variant_path(product, foreign_variant)
    assert_response :not_found
    post admin_product_variants_path(product), params: { revision: product.draft_revision, variant: { name: "Wrong source", price: "1", source_id: foreign_variant.id } }
    assert_response :unprocessable_entity
  end

  test "history retains each variant availability transition actor and timestamp after later edits" do
    product = create_product
    variant = product.children.variants.sole
    state = VariantAvailability.find_by!(recording: variant)
    actor = users(:two).person
    state.change!(available: true, person: actor, reason: "Staff availability change")
    state.change!(available: false, person: actor, reason: "Product archived")
    variant.revise_content!({ name: "Renamed variant", price: "5.95" }, revision: variant.reload.draft_revision)

    get admin_product_path(product)
    assert_response :success
    assert_select ".catalogue__record", text: /Availability changed/, count: 2 do |rows|
      rows.each do |row|
        assert_match "Default", row.text
        assert_match actor.person_card.name, row.text
        assert_select row, "time[datetime]", count: 1
      end
    end
    assert_select "p", text: "Sold out → Available · Staff availability change"
    assert_select "p", text: "Available → Sold out · Product archived"
    refute state.reload.available?
  end

  test "history shows newest events first and relationship names as recorded" do
    travel_to 1.second.from_now do
      product = create_product
      patch admin_product_path(product), params: { revision: product.reload.draft_revision, product: { name: "Wings", category_ids: [ @category.id ] } }
      assert_response :see_other
      @category.update!(recordable: Category.new(name: "Later name"))
      variant = product.children.variants.sole
      variant.update!(recordable: Variant.new(name: "Large", price: "8.50"))

      get admin_product_path(product)
      assert_response :success
      expected_ids = product.timeline_events.reorder(created_at: :desc, id: :desc).map { |event| "history_event_#{event.id}" }
      assert_select "article[id^=history_event_]" do |rows|
        assert_equal expected_ids, rows.map { |row| row["id"] }
      end
      assert_select "ins", text: "Starters"
      assert_select "ins", text: "Later name", count: 0
    end
  end

  private

  def create_product(**attributes)
    draft = Product::Draft.new(bucket: @bucket, name: "Wings", price: "5.95", **attributes)
    assert draft.save, draft.errors.full_messages.join(", ")
    draft.recording.reload
  end
end
