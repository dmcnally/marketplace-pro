require "test_helper"

class Admin::CsvImportsControllerTest < ActionDispatch::IntegrationTest
  include CsvImportTestHelper
  include ActiveJob::TestHelper

  setup do
    @user = users(:two)
    @bucket = buckets(:default)
    @source_file = fixture_file_upload(
      Rails.root.join("test/examples/rows.csv"),
      "text/csv"
    )
  end

  test "lists only the current bucket's imports with the newest first" do
    sign_in_with_role(:admin)
    older_import = travel_to(1.day.ago) { create_import }
    newer_import = create_import(filename: "rows_invalid.csv")
    other_import = create_import(bucket: Bucket.create!(name: "Other"))

    get admin_csv_imports_path

    assert_response :success
    assert_select ".import-list__item > a" do |import_links|
      assert_equal [
        admin_csv_import_path(newer_import),
        admin_csv_import_path(older_import)
      ], import_links.map { |import_link| import_link["href"] }
    end
    assert_select "a[href='#{admin_csv_import_path(other_import)}']", count: 0
  end

  test "shows an empty message when there are no imports" do
    sign_in_with_role(:admin)

    get admin_csv_imports_path

    assert_response :success
    assert_select "p", text: "No imports yet."
  end

  test "forbids listing imports for a viewer" do
    sign_in_with_role(:viewer)

    get admin_csv_imports_path

    assert_response :forbidden
  end

  test "redirects guests to sign in" do
    get admin_csv_imports_path

    assert_redirected_to new_session_path
  end

  test "shows all import rows by default" do
    sign_in_with_role(:admin)
    import = create_import(filename: "rows_invalid.csv", processed: true)

    get admin_csv_import_path(import)

    assert_response :success
    assert_select "h1", text: "rows_invalid.csv"
    assert_select 'section[aria-label="Row 1"]', count: 1
    assert_select 'section[aria-label="Row 2"]', count: 1
  end

  test "shows only rows with errors when filtering by errors" do
    sign_in_with_role(:admin)
    import = create_import(filename: "rows_invalid.csv", processed: true)

    get admin_csv_import_path(import), params: { filter: "errors" }

    assert_response :success
    assert_select 'section[aria-label="Row 1"]', count: 1
    assert_select 'section[aria-label="Row 2"]', count: 0
  end

  test "shows only valid rows when filtering by valid" do
    sign_in_with_role(:admin)
    import = create_import(filename: "rows_invalid.csv", processed: true)

    get admin_csv_import_path(import), params: { filter: "valid" }

    assert_response :success
    assert_select 'section[aria-label="Row 1"]', count: 0
    assert_select 'section[aria-label="Row 2"]', count: 1
    assert_select "dd", text: "Valid row"
  end

  test "returns not found for an unknown row filter" do
    sign_in_with_role(:admin)
    import = create_import

    get admin_csv_import_path(import), params: { filter: "unknown" }

    assert_response :not_found
  end

  test "returns not found when viewing another bucket's import" do
    sign_in_with_role(:admin)
    other_import = create_import(bucket: Bucket.create!(name: "Other"))

    get admin_csv_import_path(other_import)

    assert_response :not_found
  end

  test "returns not found when viewing a missing import" do
    sign_in_with_role(:admin)

    get admin_csv_import_path(0)

    assert_response :not_found
  end

  test "forbids viewing an import for a viewer" do
    sign_in_with_role(:viewer)
    import = create_import

    get admin_csv_import_path(import)

    assert_response :forbidden
  end

  test "shows the available import types" do
    sign_in_with_role(:admin)

    get new_admin_csv_import_path

    assert_response :success
    assert_select 'a[href="/admin/csv_imports/new?import_type=test_rows"]',
      text: "Test rows"
    assert_select 'form[action="/admin/csv_imports"]', count: 0
  end

  test "shows the upload form for a selected import type" do
    sign_in_with_role(:admin)

    get new_admin_csv_import_path, params: { import_type: "test_rows" }

    assert_response :success
    assert_select 'form[action="/admin/csv_imports"][method="post"]' do
      assert_select 'input[name="csv_import[import_type]"][value="test_rows"]'
      assert_select 'input[type="file"][name="csv_import[source_file]"]'
      assert_select 'input[type="submit"][value="Upload CSV"]'
    end
  end

  test "returns not found for an unavailable import type" do
    sign_in_with_role(:admin)

    get new_admin_csv_import_path, params: { import_type: "unknown_type" }

    assert_response :not_found
  end

  test "forbids opening the upload page for a viewer" do
    sign_in_with_role(:viewer)

    get new_admin_csv_import_path

    assert_response :forbidden
  end

  test "uploads and processes a CSV for the signed-in person" do
    sign_in_with_role(:admin)

    assert_difference "CsvImport.count", 1 do
      perform_enqueued_jobs do
        post admin_csv_imports_path, params: upload_params
      end
    end

    import = @bucket.csv_imports.sole
    assert_equal @user.person, import.created_by
    assert_equal "test_rows", import.import_type
    assert_equal "rows.csv", import.source_file.filename.to_s
    assert_redirected_to admin_csv_import_path(import)

    follow_redirect!

    assert_response :success
    assert_select "h1", text: "rows.csv"
    assert_select "section[aria-label^='Row ']", count: 3
    assert_select "dd", text: "First row"
  end

  test "ignores submitted ownership and uses the signed-in person's current bucket" do
    sign_in_with_role(:admin)
    other_bucket = Bucket.create!(name: "Other")

    assert_difference "CsvImport.count", 1 do
      post admin_csv_imports_path, params: upload_params(
        bucket_id: other_bucket.id,
        created_by_id: users(:one).person.id
      )
    end

    import = CsvImport.order(:id).last
    assert_equal @bucket, import.bucket
    assert_equal @user.person, import.created_by
    assert_redirected_to admin_csv_import_path(import)
  end

  test "shows errors without creating an import when the file is missing" do
    sign_in_with_role(:admin)

    assert_no_difference "CsvImport.count" do
      post admin_csv_imports_path, params: upload_params(source_file: nil)
    end

    assert_response :unprocessable_entity
    assert_select ".form-errors", text: /Source file/
    assert_select 'input[type="file"][name="csv_import[source_file]"]'
  end

  test "shows errors without creating an import when the import type is unavailable" do
    sign_in_with_role(:admin)

    assert_no_difference "CsvImport.count" do
      post admin_csv_imports_path,
        params: upload_params(import_type: "unknown_type")
    end

    assert_response :unprocessable_entity
    assert_select ".form-errors", text: /Import type/
  end

  test "forbids uploading an import for a viewer" do
    sign_in_with_role(:viewer)

    assert_no_difference "CsvImport.count" do
      post admin_csv_imports_path, params: upload_params
    end

    assert_response :forbidden
  end

  test "deletes an import and returns to the imports page" do
    sign_in_with_role(:admin)
    import = create_import

    assert_difference "CsvImport.count", -1 do
      delete admin_csv_import_path(import)
    end

    assert_response :see_other
    assert_redirected_to admin_csv_imports_path

    follow_redirect!

    assert_response :success
    assert_select "p", text: "No imports yet."
  end

  test "forbids deleting an import for a viewer" do
    sign_in_with_role(:viewer)
    import = create_import

    assert_no_difference "CsvImport.count" do
      delete admin_csv_import_path(import)
    end

    assert_response :forbidden
    assert CsvImport.exists?(import.id)
  end

  test "does not delete another bucket's import" do
    sign_in_with_role(:admin)
    other_import = create_import(bucket: Bucket.create!(name: "Other"))

    assert_no_difference "CsvImport.count" do
      delete admin_csv_import_path(other_import)
    end

    assert_response :not_found
    assert CsvImport.exists?(other_import.id)
  end

  test "returns not found when deleting a missing import" do
    sign_in_with_role(:admin)

    assert_no_difference "CsvImport.count" do
      delete admin_csv_import_path(0)
    end

    assert_response :not_found
  end

  private

  def sign_in_with_role(role)
    Membership.create!(person: @user.person, bucket: @bucket, role: role)
    sign_in_as @user
  end

  def create_import(**attributes)
    create_csv_import(
      bucket: @bucket,
      created_by: @user.person,
      **attributes
    )
  end

  def upload_params(**attributes)
    {
      csv_import: {
        import_type: "test_rows",
        source_file: @source_file,
        **attributes
      }
    }
  end
end
