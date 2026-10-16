require "test_helper"
require_relative "../../test_helpers/catalogue_test_helper"

class Catalogue::OverviewsControllerTest < ActionDispatch::IntegrationTest
  include CatalogueTestHelper

  setup do
    @bucket = Current.bucket
    @membership = Membership.create!(person: users(:two).person, bucket: @bucket, role: :viewer)
    sign_in_as users(:two)
    @product = create_catalogue_product(name: "Published wings")
    @regular = @product.children.variants.sole
    @large = add_catalogue_variant(@product)
    @milk = @bucket.recordings.create!(recordable: Allergen.new(name: "Milk"))
    @regular.revise_content!({ name: "Regular", price: 5, allergen_ids: [ @milk.id ] }, revision: @regular.reload.draft_revision)
    publication = Product::Publication.new(@product.reload)
    publication.publish!(token: publication.review_token)
    @menu = create_catalogue_menu
    add_menu_section(@menu, product_ids: [ @product.id ])
    add_menu_section(@menu, name: "Sharing", product_ids: [ @product.id ])
    publication = Menu::Publication.new(@menu.reload)
    publication.publish!(token: publication.review_token)
  end

  test "staff sees each product once with published content and no admin warnings or links" do
    draft = Product::Draft.for(@product.reload)
    draft.name = "Draft wings"
    assert draft.save
    add_catalogue_variant(@product, name: "Draft only")
    @milk.revise_content!({ name: "Dairy" }, revision: @milk.draft_revision)
    get overview_path
    assert_response :success
    assert_select "h2", text: "Published wings", count: 1
    assert_select "p", /Milk · Sold out/
    assert_select "strong", /Regular · 5.00 GBP/
    assert_select "h2", text: "Draft wings", count: 0
    assert_select "strong", text: /Draft only/, count: 0
    assert_select "[role=alert]", count: 0
    assert_select "a", text: "Admin", count: 0
    assert_select "button", text: "Make available", count: 2
    assert_select "button", "All available"
    @membership.update!(role: :editor)
    get overview_path
    assert_select "a[href=?]", admin_products_path, text: "Products"
    assert_select "a", text: "Admin", count: 0
    assert_select "h2", text: "Review live allergen information", count: 0
    get admin_products_path
    assert_select "a[href=?]", overview_path, text: "Overview"
  end

  test "individual and bulk controls update through Turbo with HTML fallback and attributed events" do
    post availability_path, params: { recording_id: @regular.id }, as: :turbo_stream
    assert_response :success
    assert_select "turbo-stream[action=replace][target=live-overview]"
    assert_match "1 of 2 available", response.body
    assert_match "Mark sold out", response.body
    assert_equal users(:two).person, @regular.events.find_by!(action: "availability_changed").person
    assert_difference "Event.count", 1 do
      post availability_path, params: { recording_id: @product.id }, as: :turbo_stream
    end
    assert_response :success
    assert_match "2 of 2 available", response.body
    delete availability_path, params: { recording_id: @product.id }
    assert_redirected_to overview_path
    follow_redirect!
    assert_select "p", "Published variants · 0 of 2 available"
  end

  test "ineligible and foreign targets cannot be changed and stale controls refresh the menu" do
    outside = create_catalogue_product
    draft = add_catalogue_variant(@product, name: "Draft only")
    [ outside, outside.children.variants.sole, draft ].each do |recording|
      assert_no_difference "Event.count" do
        post availability_path, params: { recording_id: recording.id }, as: :turbo_stream
      end
      assert_response :forbidden
      assert_match "Availability could not be changed", response.body
    end
    foreign = create_catalogue_product(bucket: Bucket.create!(name: "Other"))
    post availability_path, params: { recording_id: foreign.id }
    assert_response :not_found
    publication = Menu::Publication.new(@menu.reload)
    publication.unpublish!(token: publication.review_token)
    post availability_path, params: { recording_id: @regular.id }, as: :turbo_stream
    assert_response :forbidden
    assert_match "No live menu", response.body
    refute VariantAvailability.find_by!(recording: @regular).available?
  end

  test "empty live menu and no live menu have no availability controls" do
    @product.archive_content!(revision: @product.reload.draft_revision)
    get overview_path
    assert_select "h2", "No visible products"
    assert_select "form[action=?]", availability_path, count: 0
    @menu.archive_content!(revision: @menu.reload.draft_revision)
    get overview_path
    assert_select "h2", "No live menu"
    assert_select "form[action=?]", availability_path, count: 0
  end

  test "guests and people without membership cannot use the staff endpoints" do
    delete session_path
    get overview_path
    assert_redirected_to new_session_path
    post availability_path, params: { recording_id: @regular.id }
    assert_redirected_to new_session_path
    sign_in_as users(:two)
    @membership.destroy!
    get overview_path
    assert_redirected_to no_bucket_path
    assert_no_difference "Event.count" do
      post availability_path, params: { recording_id: @regular.id }
    end
    assert_redirected_to no_bucket_path
  end
end
