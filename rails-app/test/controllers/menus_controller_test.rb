require "test_helper"
require_relative "../test_helpers/catalogue_test_helper"

class MenusControllerTest < ActionDispatch::IntegrationTest
  include CatalogueTestHelper

  setup do
    @bucket = Current.bucket
    @membership = Membership.create!(person: users(:two).person, bucket: @bucket, role: :editor)
    sign_in_as users(:two)
  end

  test "create menu and sections select shared products reorder and preserve removed section history" do
    product = create_catalogue_product
    bread = create_catalogue_product(name: "Bread")
    get admin_menus_path
    assert_response :success
    assert_select "p", /No menus yet/
    post admin_menus_path, params: { menu: { name: "Evening menu" } }
    menu = @bucket.recordings.menus.sole
    assert_redirected_to edit_admin_menu_path(menu)
    get new_admin_menu_section_path(menu)
    assert_response :success
    post admin_menu_sections_path(menu), params: { revision: menu.reload.draft_revision, menu_section: { name: "Starters", product_ids: [ product.id, bread.id ] } }
    assert_response :see_other
    first = menu.children.menu_sections.sole
    post admin_menu_sections_path(menu), params: { revision: menu.reload.draft_revision, menu_section: { name: "Sharing", product_ids: [ product.id ] } }
    assert_response :see_other
    second = menu.children.menu_sections.order(:id).last
    get edit_admin_menu_path(menu)
    assert_response :success
    assert_select ".catalogue__notice", "Also in Sharing"
    assert_select ".catalogue__notice", "Also in Starters"
    post admin_menu_section_order_path(menu), params: { revision: menu.reload.draft_revision, positions: { first.id => 2, second.id => 1 } }
    assert_response :see_other
    assert_equal [ second.id, first.id ], menu.reload.recordable.section_order
    post admin_menu_section_product_order_path(menu, first), params: { revision: menu.draft_revision, positions: { product.id => 2, bread.id => 1 } }
    assert_response :see_other
    assert_equal [ bread.id, product.id ], first.reload.recordable.product_ids
    get edit_admin_menu_section_path(menu, first)
    assert_response :success
    patch admin_menu_section_path(menu, first), params: { revision: menu.reload.draft_revision, menu_section: { name: "Small plates", product_ids: [ bread.id ] } }
    assert_response :see_other
    assert_equal [ bread.id ], first.reload.recordable.product_ids
    get admin_menu_path(menu)
    assert_response :success
    assert_select "ins", /Small plates/
    delete admin_menu_section_path(menu, first), params: { revision: menu.reload.draft_revision }
    assert_response :see_other
    assert first.reload.persisted?
    assert_equal [ second.id ], menu.reload.recordable.section_order
  end

  test "menu history puts newest section changes first even at the same timestamp" do
    freeze_time do
      menu = create_catalogue_menu
      section = add_menu_section(menu)
      section.update!(recordable: MenuSection.new(name: "Latest section"))
      get admin_menu_path(menu)
      assert_response :success
      assert_select "article[id^=history_event_]" do |rows|
        assert_equal "history_event_#{section.events.order(:id).last.id}", rows.first["id"]
        assert_equal "history_event_#{menu.events.order(:id).first.id}", rows.last["id"]
      end
    end
  end

  test "validation preserves submitted values and stale requests cannot change newer content" do
    post admin_menus_path, params: { menu: { name: "", description: "Keep this" } }
    assert_response :unprocessable_entity
    assert_select "textarea", "Keep this"
    menu = create_catalogue_menu
    revision = menu.draft_revision
    patch admin_menu_path(menu), params: { revision: revision, menu: { name: "New name" } }
    assert_response :see_other
    patch admin_menu_path(menu), params: { revision: revision, menu: { name: "Stale" } }
    assert_response :conflict
    assert_equal "New name", menu.reload.recordable.name
    product = create_catalogue_product
    post admin_menu_sections_path(menu), params: { revision: menu.draft_revision, menu_section: { name: "Repeated", product_ids: [ product.id, product.id ] } }
    assert_response :unprocessable_entity
    assert_select "[role=alert]", /same product twice/
  end

  test "preview shows published content and blockers without publishing anything" do
    menu = create_catalogue_menu
    product = create_catalogue_product
    publication = Product::Publication.new(product)
    publication.publish!(token: publication.review_token)
    product.revise_content!(product.recordable.attributes.except("id").merge("name" => "Hidden draft"), revision: product.draft_revision)
    lemonade = create_catalogue_product(name: "Lemonade")
    add_menu_section(menu, product_ids: [ product.id, lemonade.id ])
    assert_no_difference [ "Catalogue::Snapshot.count", "Event.count" ] do
      get admin_menu_preview_path(menu)
    end
    assert_response :success
    assert_select "strong", "Wings"
    assert_select "strong", text: "Hidden draft", count: 0
    assert_select "[role=alert]", /Lemonade has no published version/
    assert_select "p", /5.95 GBP · Sold out/
  end

  test "viewers cannot edit or preview and foreign menu sections cannot be targeted" do
    menu = create_catalogue_menu
    section = add_menu_section(menu)
    other = create_catalogue_menu
    get edit_admin_menu_section_path(other, section)
    assert_response :not_found
    @membership.update!(role: :viewer)
    [ admin_menus_path, edit_admin_menu_path(menu), admin_menu_path(menu), admin_menu_preview_path(menu), new_admin_menu_section_path(menu), recording_diff_path(section) ].each do |path|
      get path
      assert_response :forbidden
    end
    assert_no_difference [ "Menu.count", "MenuSection.count", "Event.count" ] do
      post admin_menus_path, params: { menu: { name: "Denied" } }
      assert_response :forbidden
      patch admin_menu_path(menu), params: { revision: menu.reload.draft_revision, menu: { name: "Denied" } }
      assert_response :forbidden
      post admin_menu_sections_path(menu), params: { menu_section: { name: "Denied" } }
      assert_response :forbidden
      patch admin_menu_section_path(menu, section), params: { menu_section: { name: "Denied" } }
      assert_response :forbidden
      delete admin_menu_section_path(menu, section)
      assert_response :forbidden
      post admin_menu_section_order_path(menu)
      assert_response :forbidden
      post admin_menu_section_product_order_path(menu, section)
      assert_response :forbidden
    end
  end
end
