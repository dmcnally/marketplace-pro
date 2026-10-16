require "test_helper"

class CategoryActionsTest < ActiveSupport::TestCase
  class View
    def new_admin_category_path = "/admin/categories/new"
    def edit_admin_category_path(recording) = "/admin/categories/#{recording.id}/edit"
    def admin_category_path(recording) = "/admin/categories/#{recording.id}"
    def admin_category_archive_path(recording) = "/admin/categories/#{recording.id}/archive"
    def link_to(label, path, **options) = { label: label, path: path, options: options }
    def button_to(label, path, **options) = { label: label, path: path, options: options }
    def render(partial, **locals) = { partial: partial, locals: locals }
  end

  test "editor controls reflect active and archived state" do
    Membership.create!(person: Current.person, bucket: Current.bucket, role: :editor)
    recording = Current.bucket.recordings.create!(recordable: Category.new(name: "Food"))
    actions = CategoryActions.new(view: View.new, person: Current.person, bucket: Current.bucket)
    assert_equal "Add category", actions.new_link[:label]
    assert_equal "Edit category", actions.edit_link_for(recording)[:label]
    assert_equal "categories/form", actions.form_for(recording)[:partial]
    assert_equal recording.draft_revision, actions.archive_button_for(recording)[:options][:params][:revision]
    assert_nil actions.restore_button_for(recording)
    recording.archive_content!(revision: recording.draft_revision)
    assert_nil actions.edit_link_for(recording)
    assert_nil actions.archive_button_for(recording)
    assert_nil actions.form_for(recording)
    assert_equal "Restore category", actions.restore_button_for(recording)[:label]
    assert_equal "History", actions.history_link_for(recording)[:label]
  end

  test "viewers and guests receive no management controls" do
    Membership.create!(person: Current.person, bucket: Current.bucket, role: :viewer)
    recording = Current.bucket.recordings.create!(recordable: Category.new(name: "Food"))
    [ Current.person, GuestPerson.new ].each do |person|
      actions = CategoryActions.new(view: View.new, person: person, bucket: Current.bucket)
      assert_nil actions.new_link
      assert_nil actions.edit_link_for(recording)
      assert_nil actions.archive_button_for(recording)
      assert_nil actions.restore_button_for(recording)
      assert_nil actions.history_link_for(recording)
      assert_nil actions.form_for(recording)
    end
  end
end
