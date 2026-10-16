require "test_helper"
require_relative "../../test_helpers/catalogue_test_helper"

class Products::PublicationsControllerTest < ActionDispatch::IntegrationTest
  include CatalogueTestHelper

  setup do
    @bucket = Current.bucket
    @membership = Membership.create!(person: users(:two).person, bucket: @bucket, role: :editor)
    sign_in_as users(:two)
    @product = create_catalogue_product
  end

  test "review and publish all variants then unpublish with history preserved" do
    get new_admin_product_publication_path(@product)
    assert_response :success
    assert_select "h1", "Publish Wings?"
    assert_select "p", text: /Not published → 5.95/
    token = css_select("input[name='review_token']").first["value"]
    assert_difference "Catalogue::Snapshot.count", 1 do
      post admin_product_publication_path(@product), params: { review_token: token }
    end
    assert_response :see_other
    publication = Product::Publication.new(@product.reload)
    assert publication.published?
    assert_equal users(:two).person, @product.events.find_by!(action: "published").person
    get edit_admin_product_path(@product)
    assert_response :success
    assert_select "p", text: /Published · Availability/
    assert_no_difference "Catalogue::Snapshot.count" do
      delete admin_product_publication_path(@product), params: { review_token: publication.review_token }
    end
    assert_response :see_other
    refute publication.published?
    assert @product.events.exists?(action: "unpublished")
  end

  test "missing and stale confirmations cannot publish" do
    token = Product::Publication.new(@product).review_token
    @product.revise_content!({ name: "Changed" }, revision: @product.draft_revision)
    [ nil, token ].each do |review_token|
      assert_no_difference "Catalogue::Snapshot.count" do
        post admin_product_publication_path(@product), params: { review_token: review_token }
      end
      assert_response :conflict
    end
  end

  test "viewer requests cannot review publish or unpublish" do
    @membership.update!(role: :viewer)
    get new_admin_product_publication_path(@product)
    assert_response :forbidden
    assert_no_difference "Catalogue::Snapshot.count" do
      post admin_product_publication_path(@product), params: { review_token: Product::Publication.new(@product).review_token }
      assert_response :forbidden
      delete admin_product_publication_path(@product)
      assert_response :forbidden
    end
  end

  test "foreign products are outside publication lookup" do
    other = create_catalogue_product(bucket: Bucket.create!(name: "Elsewhere"))
    get new_admin_product_publication_path(other)
    assert_response :not_found
    post admin_product_publication_path(other)
    assert_response :not_found
  end
end
