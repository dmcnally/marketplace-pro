require "test_helper"

class Admin::CsvImportActionsTest < ActionView::TestCase
  setup do
    @import = CsvImport.new(id: 42)
    @membership = Membership.create!(
      person: Current.person,
      bucket: Current.bucket,
      role: :admin
    )

    view.extend(Rails.application.routes.url_helpers)
  end

  test "shows a link to all records for the import when viewing is allowed" do
    render html: actions.link_to_all_records(@import)

    assert_select 'a[href="/admin/csv_imports/42"]',
      text: "All records",
      count: 1
  end

  test "shows a link to records with errors for the import when viewing is allowed" do
    render html: actions.link_to_errors(@import)

    assert_select 'a[href="/admin/csv_imports/42?filter=errors"]',
      text: "Errors",
      count: 1
  end

  test "shows a link to valid records for the import when viewing is allowed" do
    render html: actions.link_to_valid_records(@import)

    assert_select 'a[href="/admin/csv_imports/42?filter=valid"]',
      text: "Valid",
      count: 1
  end

  test "hides the all records link when viewing is denied" do
    @membership.update!(role: :viewer)

    assert_nil actions.link_to_all_records(@import)
  end

  test "hides the errors link when viewing is denied" do
    @membership.update!(role: :viewer)

    assert_nil actions.link_to_errors(@import)
  end

  test "hides the valid records link when viewing is denied" do
    @membership.update!(role: :viewer)

    assert_nil actions.link_to_valid_records(@import)
  end

  test "marks only the all records link as current when all records are selected" do
    render_filters(selected_filter: "all")

    assert_select "a", count: 3
    assert_select 'a[aria-current="page"]', count: 1
    assert_select 'a[aria-current="page"]', text: "All records"
  end

  test "marks only the errors link as current when errors are selected" do
    render_filters(selected_filter: "errors")

    assert_select "a", count: 3
    assert_select 'a[aria-current="page"]', count: 1
    assert_select 'a[aria-current="page"]', text: "Errors"
  end

  test "marks only the valid records link as current when valid records are selected" do
    render_filters(selected_filter: "valid")

    assert_select "a", count: 3
    assert_select 'a[aria-current="page"]', count: 1
    assert_select 'a[aria-current="page"]', text: "Valid"
  end

  private

  def actions(selected_filter: "all")
    Admin::CsvImportActions.new(
      view: view,
      person: Current.person,
      bucket: Current.bucket,
      selected_filter: selected_filter
    )
  end

  def render_filters(selected_filter:)
    filters = actions(selected_filter: selected_filter)

    render html: view.safe_join([
      filters.link_to_all_records(@import),
      filters.link_to_errors(@import),
      filters.link_to_valid_records(@import)
    ])
  end
end
