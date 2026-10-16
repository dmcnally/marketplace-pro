require "test_helper"
require_relative "../../test_helpers/catalogue_test_helper"

class Menus::ReversionsControllerTest < ActionDispatch::IntegrationTest
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
    @publication = Menu::Publication.new(@menu.reload)
    @publication.publish!(token: @publication.review_token)
  end

  test "revert review restores an unpublished menu and reports preserved archived references" do
    @publication.unpublish!(token: @publication.review_token)
    @product.archive_content!(revision: @product.draft_revision)
    Menu::Structure.new(@menu).remove!(@section, revision: @menu.draft_revision)
    get new_admin_menu_reversion_path(@menu)
    assert_response :success
    assert_select "h1", "Revert all menu changes?"
    assert_select "p", "Wings"
    token = css_select("input[name='review_token']").sole["value"]
    post admin_menu_reversion_path(@menu), params: { review_token: token }
    assert_response :see_other
    assert_includes flash[:notice], "Wings"
    assert_equal [ @section.id ], @menu.reload.recordable.section_order
    assert @product.reload.discarded?
    refute @publication.published?
    assert_equal users(:two).person, @menu.events.find_by!(action: "reverted").person
  end

  test "stale and unauthorized reverts do not change content" do
    token = @publication.review_token
    add_menu_section(@menu, name: "New draft")
    assert_no_difference [ "Menu.count", "MenuSection.count", "Event.count" ] do
      post admin_menu_reversion_path(@menu), params: { review_token: token }
    end
    assert_response :conflict
    never_published = create_catalogue_menu
    get new_admin_menu_reversion_path(never_published)
    assert_response :forbidden
    post admin_menu_reversion_path(never_published)
    assert_response :forbidden
    foreign = create_catalogue_menu(bucket: Bucket.create!(name: "Other"))
    post admin_menu_reversion_path(foreign)
    assert_response :not_found
    @membership.update!(role: :viewer)
    get new_admin_menu_reversion_path(@menu)
    assert_response :forbidden
    assert_no_difference "Event.count" do
      post admin_menu_reversion_path(@menu), params: { review_token: @publication.review_token }
    end
    assert_response :forbidden
  end
end
