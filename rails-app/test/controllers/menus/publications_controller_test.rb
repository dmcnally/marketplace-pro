require "test_helper"
require_relative "../../test_helpers/catalogue_test_helper"

class Menus::PublicationsControllerTest < ActionDispatch::IntegrationTest
  include CatalogueTestHelper

  setup do
    @bucket = Current.bucket
    @membership = Membership.create!(person: users(:two).person, bucket: @bucket, role: :editor)
    sign_in_as users(:two)
    @product = create_catalogue_product
    product_publication = Product::Publication.new(@product)
    product_publication.publish!(token: product_publication.review_token)
    @menu = create_catalogue_menu
    @section = add_menu_section(@menu, product_ids: [ @product.id ])
    @menu.reload
  end

  test "review publishes a menu and replacement confirmation identifies the current live menu" do
    get new_admin_menu_publication_path(@menu)
    assert_response :success
    assert_select "h2", "This will become the only live menu"
    token = css_select("input[name='review_token']").sole["value"]
    post admin_menu_publication_path(@menu), params: { review_token: token }
    assert_response :see_other
    assert @menu.catalogue_published?
    get edit_admin_menu_path(@menu)
    assert_select "p", /Live · Presentation/
    other = create_catalogue_menu(name: "Lunch")
    add_menu_section(other, product_ids: [ @product.id ])
    get new_admin_menu_publication_path(other)
    assert_response :success
    assert_select "h2", "This replaces Evening menu"
    token = css_select("input[name='review_token']").sole["value"]
    post admin_menu_publication_path(other), params: { review_token: token }
    assert_response :see_other
    assert_equal other, Catalogue::Release.live_menu(@bucket).recording
    refute @menu.catalogue_published?
    assert_equal users(:two).person, @menu.events.find_by!(action: "unpublished").person
    get new_admin_menu_publication_path(other, intent: "unpublish")
    assert_response :success
    assert_select "h2", "There will be no live menu"
    token = css_select("input[name='review_token']").sole["value"]
    delete admin_menu_publication_path(other), params: { review_token: token }
    assert_response :see_other
    assert_nil Catalogue::Release.live_menu(@bucket)
  end

  test "blockers are named and cannot be bypassed by posting directly" do
    unpublished = create_catalogue_product(name: "Lemonade")
    add_menu_section(@menu, name: "Drinks", product_ids: [ unpublished.id ])
    get new_admin_menu_publication_path(@menu)
    assert_response :success
    assert_select "[role=alert]", /Lemonade has no published version/
    assert_select "button", text: "Publish menu", count: 0
    assert_select "a[href=?]", edit_admin_product_path(unpublished)
    publication = Menu::Publication.new(@menu.reload)
    assert_no_difference [ "Catalogue::Release.count", "Catalogue::Snapshot.count" ] do
      post admin_menu_publication_path(@menu), params: { review_token: publication.review_token }
    end
    assert_response :unprocessable_entity
  end

  test "stale confirmation rejects changed structure without replacing live state" do
    publication = Menu::Publication.new(@menu)
    token = publication.review_token
    add_menu_section(@menu, name: "New section")
    assert_no_difference "Catalogue::Snapshot.count" do
      post admin_menu_publication_path(@menu), params: { review_token: token }
    end
    assert_response :conflict
    assert_select "a[href=?]", new_admin_menu_publication_path(@menu)
  end

  test "viewers and foreign menus cannot access publication endpoints" do
    foreign = create_catalogue_menu(bucket: Bucket.create!(name: "Other"))
    get new_admin_menu_publication_path(foreign)
    assert_response :not_found
    post admin_menu_publication_path(foreign)
    assert_response :not_found
    @membership.update!(role: :viewer)
    get new_admin_menu_publication_path(@menu)
    assert_response :forbidden
    assert_no_difference [ "Catalogue::Release.count", "Event.count" ] do
      post admin_menu_publication_path(@menu)
      assert_response :forbidden
      delete admin_menu_publication_path(@menu)
      assert_response :forbidden
    end
  end
end
