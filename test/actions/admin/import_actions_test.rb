require "test_helper"

class Admin::ImportActionsTest < ActionView::TestCase
  include CsvImportTestHelper

  setup do
    view.extend(Rails.application.routes.url_helpers)
  end

  test "shows the new import link when creating imports is allowed" do
    person = Current.person
    bucket = Current.bucket
    Membership.create!(person: person, bucket: bucket, role: :admin)

    actions = Admin::ImportActions.new(
      view: view,
      person: person,
      bucket: bucket
    )

    render html: actions.new_import

    assert_select 'a[href="/admin/csv_imports/new"]',
      text: "New Import",
      count: 1
  end

  test "hides the new import link when creating imports is denied" do
    person = Current.person
    bucket = Current.bucket
    Membership.create!(person: person, bucket: bucket, role: :viewer)

    actions = Admin::ImportActions.new(
      view: view,
      person: person,
      bucket: bucket
    )

    assert_nil actions.new_import
  end

  test "shows the back to imports link when viewing imports is allowed" do
    person = Current.person
    bucket = Current.bucket
    Membership.create!(person: person, bucket: bucket, role: :admin)

    actions = Admin::ImportActions.new(
      view: view,
      person: person,
      bucket: bucket
    )

    render html: actions.index_back_link

    assert_select 'a[href="/admin/csv_imports"]',
      text: "Back to Imports",
      count: 1
  end

  test "hides the back to imports link when viewing imports is denied" do
    person = Current.person
    bucket = Current.bucket
    Membership.create!(person: person, bucket: bucket, role: :viewer)

    actions = Admin::ImportActions.new(
      view: view,
      person: person,
      bucket: bucket
    )

    assert_nil actions.index_back_link
  end

  test "shows a link to an available import type when creating imports is allowed" do
    person = Current.person
    bucket = Current.bucket
    Membership.create!(person: person, bucket: bucket, role: :admin)

    actions = Admin::ImportActions.new(
      view: view,
      person: person,
      bucket: bucket
    )

    render html: actions.type_link_for("test_rows")

    assert_select 'a[href="/admin/csv_imports/new?import_type=test_rows"]',
      text: "Test rows",
      count: 1
  end

  test "hides the import type link when creating imports is denied" do
    person = Current.person
    bucket = Current.bucket
    Membership.create!(person: person, bucket: bucket, role: :viewer)

    actions = Admin::ImportActions.new(
      view: view,
      person: person,
      bucket: bucket
    )

    assert_nil actions.type_link_for("test_rows")
  end

  test "hides the link for an unavailable import type" do
    person = Current.person
    bucket = Current.bucket
    Membership.create!(person: person, bucket: bucket, role: :admin)

    actions = Admin::ImportActions.new(
      view: view,
      person: person,
      bucket: bucket
    )

    assert_nil actions.type_link_for("unknown_type")
  end

  test "marks the selected import type link as current" do
    person = Current.person
    bucket = Current.bucket
    Membership.create!(person: person, bucket: bucket, role: :admin)

    actions = Admin::ImportActions.new(
      view: view,
      person: person,
      bucket: bucket
    )

    render html: actions.type_link_for(
      "test_rows",
      selected_type: "test_rows"
    )

    assert_select 'a[href="/admin/csv_imports/new?import_type=test_rows"][aria-current="page"]',
      text: "Test rows",
      count: 1
  end

  test "does not mark an import type link as current when no type is selected" do
    person = Current.person
    bucket = Current.bucket
    Membership.create!(person: person, bucket: bucket, role: :admin)

    actions = Admin::ImportActions.new(
      view: view,
      person: person,
      bucket: bucket
    )

    render html: actions.type_link_for("test_rows")

    assert_select 'a[href="/admin/csv_imports/new?import_type=test_rows"]',
      text: "Test rows",
      count: 1
    assert_select "a[aria-current]", count: 0
  end

  test "shows a cancel link back to imports" do
    person = Current.person
    bucket = Current.bucket
    Membership.create!(person: person, bucket: bucket, role: :admin)

    actions = Admin::ImportActions.new(
      view: view,
      person: person,
      bucket: bucket
    )

    render html: actions.form_cancel_link

    assert_select 'a[href="/admin/csv_imports"]',
      text: "Cancel",
      count: 1
  end

  test "shows the cancel link even when creating imports is denied" do
    person = Current.person
    bucket = Current.bucket
    Membership.create!(person: person, bucket: bucket, role: :viewer)

    actions = Admin::ImportActions.new(
      view: view,
      person: person,
      bucket: bucket
    )

    render html: actions.form_cancel_link

    assert_select 'a[href="/admin/csv_imports"]',
      text: "Cancel",
      count: 1
  end
end
