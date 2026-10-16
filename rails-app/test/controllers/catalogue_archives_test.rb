require "test_helper"
require_relative "../test_helpers/catalogue_test_helper"

class CatalogueArchivesTest < ActionDispatch::IntegrationTest
  include CatalogueTestHelper

  setup do
    @bucket = Current.bucket
    @membership = Membership.create!(person: users(:two).person, bucket: @bucket, role: :editor)
    sign_in_as users(:two)
    @product = create_catalogue_product
    @variant = @product.children.variants.sole
    @menu = create_catalogue_menu
  end

  test "product confirmation archive listing and restore preserve history" do
    get new_admin_product_archive_path(@product)
    assert_response :success
    assert_select "h2", "Archive Wings?"
    revision = css_select("input[name=revision]").sole["value"]
    post admin_product_archive_path(@product), params: { revision: revision }
    assert_redirected_to admin_archived_products_path
    follow_redirect!
    assert_select "strong", "Wings"
    assert_select "button", "Restore product"
    assert_select "a[href=?]", admin_product_path(@product)
    get admin_products_path
    assert_select "strong", text: "Wings", count: 0
    get edit_admin_product_path(@product)
    assert_response :forbidden
    delete admin_product_archive_path(@product), params: { revision: @product.reload.draft_revision }
    assert_redirected_to edit_admin_product_path(@product)
    follow_redirect!
    assert_select "h1", "Wings"
    assert_equal users(:two).person, @product.events.find_by!(action: "restored").person
    refute VariantAvailability.find_by!(recording: @variant).available?
  end

  test "variant confirmation withdraws only its target and restore works with an archived parent" do
    get edit_admin_product_variant_path(@product, @variant)
    assert_response :success
    assert_select "a[href=?]", new_admin_product_variant_archive_path(@product, @variant)
    get new_admin_product_variant_archive_path(@product, @variant)
    assert_response :success
    revision = css_select("input[name=revision]").sole["value"]
    post admin_product_variant_archive_path(@product, @variant), params: { revision: revision }
    assert_redirected_to edit_admin_product_path(@product)
    follow_redirect!
    assert_select "button", "Restore variant"
    @product.archive_content!(revision: @product.reload.draft_revision)
    get admin_archived_products_path
    assert_select "p", /Parent product archived/
    delete admin_product_variant_archive_path(@product, @variant), params: { revision: @variant.reload.draft_revision }
    assert_redirected_to admin_archived_products_path
    assert @variant.reload.kept?
    assert @product.reload.discarded?
  end

  test "menu archive listing and restore return an editable unpublished draft" do
    get new_admin_menu_archive_path(@menu)
    assert_response :success
    post admin_menu_archive_path(@menu), params: { revision: @menu.reload.draft_revision }
    assert_redirected_to admin_archived_menus_path
    follow_redirect!
    assert_select "h2", "Evening menu"
    assert_select "button", "Restore menu"
    get admin_menus_path
    assert_select "strong", text: "Evening menu", count: 0
    delete admin_menu_archive_path(@menu), params: { revision: @menu.reload.draft_revision }
    assert_redirected_to edit_admin_menu_path(@menu)
    follow_redirect!
    assert_select "h1", "Edit Evening menu"
    refute @menu.catalogue_published?
  end

  test "stale and missing revisions reject mutations" do
    [ admin_product_archive_path(@product), admin_product_variant_archive_path(@product, @variant), admin_menu_archive_path(@menu) ].each do |path|
      assert_no_difference "Event.count" do
        post path, params: { revision: "outdated" }
        assert_response :conflict
        post path
        assert_response :conflict
      end
    end
    @product.archive_content!(revision: @product.reload.draft_revision)
    delete admin_product_archive_path(@product), params: { revision: "outdated" }
    assert_response :conflict
    assert @product.reload.discarded?
  end

  test "viewer cannot read confirmations or archives or bypass controls with mutations" do
    @membership.update!(role: :viewer)
    [ admin_archived_products_path, admin_archived_menus_path, new_admin_product_archive_path(@product), new_admin_product_variant_archive_path(@product, @variant), new_admin_menu_archive_path(@menu) ].each do |path|
      get path
      assert_response :forbidden
    end
    [ admin_product_archive_path(@product), admin_product_variant_archive_path(@product, @variant), admin_menu_archive_path(@menu) ].each do |path|
      assert_no_difference "Event.count" do
        post path
        assert_response :forbidden
        delete path
        assert_response :forbidden
      end
    end
  end

  test "foreign bucket records and variants under another product cannot be addressed" do
    foreign = create_catalogue_product(bucket: Bucket.create!(name: "Other"))
    other_variant = foreign.children.variants.sole
    foreign_menu = create_catalogue_menu(bucket: foreign.bucket)
    [ new_admin_product_archive_path(foreign), new_admin_menu_archive_path(foreign_menu), new_admin_product_variant_archive_path(@product, other_variant) ].each do |path|
      get path
      assert_response :not_found
    end
    [ admin_product_archive_path(foreign), admin_menu_archive_path(foreign_menu), admin_product_variant_archive_path(@product, other_variant) ].each do |path|
      post path
      assert_response :not_found
      delete path
      assert_response :not_found
    end
    get admin_archived_products_path
    assert_response :success
    assert_select "p", "No archived products or variants."
  end
end
