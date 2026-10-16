require "test_helper"
require_relative "../test_helpers/catalogue_test_helper"

class MenuActionsTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  class View
    def new_admin_menu_path = "/admin/menus/new"
    def edit_admin_menu_path(menu) = "/admin/menus/#{menu.id}/edit"
    def admin_menu_preview_path(menu) = "/admin/menus/#{menu.id}/preview"
    def new_admin_menu_section_path(menu) = "/admin/menus/#{menu.id}/sections/new"
    def admin_menu_section_path(menu, section) = "/admin/menus/#{menu.id}/sections/#{section.id}"
    def link_to(label, path, **options) = { label: label, path: path, options: options }
    def button_to(label, path, **options) = { label: label, path: path, options: options }
    def render(partial, **locals) = { partial: partial, locals: locals }
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
