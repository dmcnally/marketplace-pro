require "test_helper"
require_relative "../../test_helpers/catalogue_test_helper"

class Products::ReversionsControllerTest < ActionDispatch::IntegrationTest
  include CatalogueTestHelper

  setup do
    @bucket = Current.bucket
    @membership = Membership.create!(person: users(:two).person, bucket: @bucket, role: :editor)
    sign_in_as users(:two)
    @product = create_catalogue_product
    @publication = Product::Publication.new(@product)
    @publication.publish!(token: @publication.review_token)
  end

  test "confirmed revert restores an unpublished draft with history and availability preserved" do
    @publication.unpublish!(token: @publication.review_token)
    @product.revise_content!(@product.recordable.attributes.except("id").merge("name" => "Changed"), revision: @product.draft_revision)
    get new_admin_product_reversion_path(@product)
    assert_response :success
    assert_select "h1", "Revert all product changes?"
    token = css_select("input[name='review_token']").sole["value"]
    assert_no_difference "Catalogue::Snapshot.count" do
      post admin_product_reversion_path(@product), params: { review_token: token }
    end
    assert_response :see_other
    assert_equal "Wings", @product.reload.recordable.name
    refute @publication.published?
    refute VariantAvailability.find_by!(recording: @product.children.variants.sole).available?
    assert_equal users(:two).person, @product.events.find_by!(action: "reverted").person
    assert @product.events.exists?(action: "updated")
  end

  test "archived references are explained before and after reverting" do
    variant = @product.children.variants.sole
    variant.archive_content!(revision: variant.draft_revision)
    get new_admin_product_reversion_path(@product)
    assert_response :success
    assert_select "strong", "Default"
    token = css_select("input[name='review_token']").sole["value"]
    post admin_product_reversion_path(@product), params: { review_token: token }
    assert_response :see_other
    assert_includes flash[:notice], "Default"
    assert variant.reload.discarded?
  end

  test "stale or missing confirmation cannot revert a newer draft" do
    token = @publication.review_token
    @product.revise_content!(@product.recordable.attributes.except("id").merge("name" => "Latest"), revision: @product.draft_revision)
    [ nil, token ].each do |review_token|
      assert_no_difference [ "Product.count", "Variant.count", "Event.count" ] do
        post admin_product_reversion_path(@product), params: { review_token: review_token }
      end
      assert_response :conflict
    end
    assert_equal "Latest", @product.reload.recordable.name
  end

  test "viewers foreign products and never published products cannot revert" do
    never_published = create_catalogue_product
    get new_admin_product_reversion_path(never_published)
    assert_response :forbidden
    post admin_product_reversion_path(never_published)
    assert_response :forbidden
    foreign = create_catalogue_product(bucket: Bucket.create!(name: "Elsewhere"))
    post admin_product_reversion_path(foreign)
    assert_response :not_found
    @membership.update!(role: :viewer)
    get new_admin_product_reversion_path(@product)
    assert_response :forbidden
    assert_no_difference "Event.count" do
      post admin_product_reversion_path(@product), params: { review_token: @publication.review_token }
    end
    assert_response :forbidden
  end
end
