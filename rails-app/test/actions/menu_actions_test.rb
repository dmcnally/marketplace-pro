require "test_helper"
require_relative "../test_helpers/catalogue_test_helper"

class MenuActionsTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  class View
    def new_admin_menu_archive_path(menu) = "/admin/menus/#{menu.id}/archive/new"
    def admin_menu_archive_path(menu) = "/admin/menus/#{menu.id}/archive"
    def new_admin_menu_publication_path(menu, **options) = "/admin/menus/#{menu.id}/publication/new"
    def admin_menu_publication_path(menu) = "/admin/menus/#{menu.id}/publication"
    def new_admin_menu_reversion_path(menu) = "/admin/menus/#{menu.id}/reversion/new"
    def admin_menu_reversion_path(menu) = "/admin/menus/#{menu.id}/reversion"
    def new_admin_menu_path = "/admin/menus/new"
    def edit_admin_menu_path(menu) = "/admin/menus/#{menu.id}/edit"
    def admin_menu_preview_path(menu) = "/admin/menus/#{menu.id}/preview"
    def new_admin_menu_section_path(menu) = "/admin/menus/#{menu.id}/sections/new"
    def admin_menu_section_path(menu, section) = "/admin/menus/#{menu.id}/sections/#{section.id}"
    def link_to(label, path, **options) = { label: label, path: path, options: options }
    def button_to(label, path, **options) = { label: label, path: path, options: options }
    def render(partial, **locals) = { partial: partial, locals: locals }
  end

  test "archive controls reflect permission and lifecycle without mutation" do
    menu = create_catalogue_menu
    actions = MenuActions.new(view: View.new, person: Current.person, bucket: Current.bucket)
    assert_nil actions.archive_link_for(menu)
    assert_nil actions.archive_button_for(menu)
    Membership.create!(person: Current.person, bucket: Current.bucket, role: :editor)
    assert_no_difference "Event.count" do
      assert_equal "Archive menu", actions.archive_link_for(menu)[:label]
      assert_equal menu.draft_revision, actions.archive_button_for(menu)[:options][:params][:revision]
      assert_nil actions.restore_button_for(menu)
    end
    menu.archive_content!(revision: menu.draft_revision)
    assert_nil actions.archive_link_for(menu)
    assert_equal :delete, actions.restore_button_for(menu)[:options][:method]
  end

  test "publication controls reflect permission blockers and prior publication" do
    menu = create_catalogue_menu
    publication = Menu::Publication.new(menu)
    actions = MenuActions.new(view: View.new, person: Current.person, bucket: Current.bucket)
    assert_nil actions.publication_link_for(menu)
    assert_nil actions.publish_button_for(publication)
    assert_nil actions.unpublish_link_for(menu)
    assert_nil actions.revert_link_for(menu)
    Membership.create!(person: Current.person, bucket: Current.bucket, role: :editor)
    assert_equal "Review & publish", actions.publication_link_for(menu)[:label]
    assert_nil actions.publish_button_for(publication)
    assert_nil actions.revert_button_for(publication)
    product = create_catalogue_product
    product_publication = Product::Publication.new(product)
    product_publication.publish!(token: product_publication.review_token)
    add_menu_section(menu, product_ids: [ product.id ])
    menu.reload
    assert_equal publication.review_token, actions.publish_button_for(publication)[:options][:params][:review_token]
    publication.publish!(token: publication.review_token)
    assert_equal :delete, actions.unpublish_button_for(publication)[:options][:method]
    assert_equal "Revert all", actions.revert_button_for(publication)[:label]
  end

  test "management controls are hidden from viewers and visible to editors without mutation" do
    menu = create_catalogue_menu
    section = add_menu_section(menu)
    draft = Menu::Draft.for(menu.reload)
    section_draft = MenuSection::Draft.for(menu, section)
    actions = MenuActions.new(view: View.new, person: Current.person, bucket: Current.bucket)
    assert_nil actions.new_link
    assert_nil actions.edit_link_for(menu)
    assert_nil actions.preview_link_for(menu)
    assert_nil actions.form_for(draft)
    assert_nil actions.section_form_for(section_draft)
    assert_nil actions.remove_section_button_for(menu, section)
    Membership.create!(person: Current.person, bucket: Current.bucket, role: :editor)
    assert_no_difference [ "Menu.count", "MenuSection.count", "Event.count" ] do
      assert_equal "Add menu", actions.new_link[:label]
      assert_equal "Edit menu", actions.edit_link_for(menu)[:label]
      assert_equal "Preview", actions.preview_link_for(menu)[:label]
      assert_equal "Add section", actions.new_section_link_for(menu)[:label]
      assert_equal "menus/form", actions.form_for(draft)[:partial]
      assert_equal "menu_sections/form", actions.section_form_for(section_draft)[:partial]
      assert_equal menu.draft_revision, actions.remove_section_button_for(menu, section)[:options][:params][:revision]
    end
    menu.archive_content!(revision: menu.draft_revision)
    assert_nil actions.edit_link_for(menu)
    assert_nil actions.new_section_link_for(menu)
  end
end
