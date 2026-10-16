require "test_helper"
require_relative "../test_helpers/catalogue_test_helper"

class AllergenWarningsTest < ActionDispatch::IntegrationTest
  include CatalogueTestHelper

  setup do
    @membership = Membership.create!(person: users(:two).person, bucket: Current.bucket, role: :editor)
    sign_in_as users(:two)
    @allergen = Current.bucket.recordings.create!(recordable: Allergen.new(name: "Milk"))
    @product = create_catalogue_product(name: "Chicken wings")
    variant = @product.children.variants.sole
    variant.revise_content!({ name: "Regular", price: 5, allergen_ids: [ @allergen.id ] }, revision: variant.draft_revision)
    publication = Product::Publication.new(@product.reload)
    publication.publish!(token: publication.review_token)
    @menu = create_catalogue_menu
    add_menu_section(@menu, product_ids: [ @product.id ])
    publication = Menu::Publication.new(@menu.reload)
    publication.publish!(token: publication.review_token)
  end

  test "allergen editing names affected live products and warnings persist until product republication" do
    get edit_admin_allergen_path(@allergen)
    assert_response :success
    assert_select "h2", "Live products affected"
    assert_select "strong", "Review Chicken wings"
    patch admin_allergen_path(@allergen), params: { revision: @allergen.reload.draft_revision, allergen: { name: "Dairy", description: "Includes lactose" } }
    assert_response :see_other
    [ admin_allergens_path, admin_products_path, edit_admin_product_path(@product) ].each do |path|
      get path
      assert_response :success
      assert_select "[role=alert]", /Chicken wings has unpublished allergen changes on Evening menu/
      assert_select "[role=alert]", /Published: Milk → Draft: Dairy: Includes lactose/
      assert_select "a[href=?]", new_admin_product_publication_path(@product)
    end
    publication = Menu::Publication.new(@menu.reload)
    publication.publish!(token: publication.review_token)
    get admin_products_path
    assert_select "[role=alert]", /Menu publication alone will not resolve/
    publication = Product::Publication.new(@product.reload)
    publication.publish!(token: publication.review_token)
    get admin_products_path
    assert_select "[role=alert]", count: 0
  end

  test "viewers cannot access warning pages or affected product details" do
    @membership.update!(role: :viewer)
    [ admin_allergens_path, edit_admin_allergen_path(@allergen), admin_products_path, edit_admin_product_path(@product) ].each do |path|
      get path
      assert_response :forbidden
      assert_select "h2", text: "Live products affected", count: 0
      assert_select "h2", text: "Review live allergen information", count: 0
    end
  end
end
