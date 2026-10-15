require "test_helper"

class ApprovalsControllerTest < ActionDispatch::IntegrationTest
  include CsvImportTestHelper
  include ActiveJob::TestHelper

  setup do
    @user = users(:two)
    @bucket = buckets(:default)
  end

  test "accepts a ready import and records who requested approval" do
    sign_in_with_role(:admin)
    import = create_import(processed: true)

    assert_difference "Approval.count", 1 do
      post approval_path, params: approval_params(import)
    end

    assert_response :success
    assert_equal @user.person, import.reload.approval.person
    assert import.approval_in_progress?
  end

  test "processes an accepted approval" do
    sign_in_with_role(:admin)
    import = create_import(processed: true)

    assert_difference -> { @bucket.recordings.articles.count }, 3 do
      perform_enqueued_jobs do
        post approval_path, params: approval_params(import)
      end
    end

    assert_response :success
    assert import.reload.approved?
  end

  test "replaces the approval control with a disabled approving button for Turbo" do
    sign_in_with_role(:admin)
    import = create_import(processed: true)
    approval_button_id = ActionView::RecordIdentifier.dom_id(
      import, :approval_button
    )

    post approval_path, params: approval_params(import), as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action='replace'][target='#{approval_button_id}']" do
      assert_select "template button[disabled]", text: "Approving", count: 1
    end
  end

  test "does not create another approval when the request is repeated" do
    sign_in_with_role(:admin)
    import = create_import(processed: true)

    post approval_path, params: approval_params(import)
    assert_response :success

    assert_no_difference "Approval.count" do
      post approval_path, params: approval_params(import)
    end

    assert_response :success
  end

  test "forbids approving an import that is already approved" do
    sign_in_with_role(:admin)
    import = create_import(processed: true)

    perform_enqueued_jobs do
      post approval_path, params: approval_params(import)
    end
    assert import.reload.approved?

    assert_no_difference "Approval.count" do
      post approval_path, params: approval_params(import)
    end

    assert_response :forbidden
  end

  test "rejects an import that has not finished processing" do
    sign_in_with_role(:admin)
    import = create_import(processed: false)

    assert_no_difference "Approval.count" do
      post approval_path, params: approval_params(import)
    end

    assert_response :unprocessable_entity
  end

  test "rejects an import containing validation errors" do
    sign_in_with_role(:admin)
    import = create_import(filename: "rows_invalid.csv", processed: true)

    assert_no_difference "Approval.count" do
      post approval_path, params: approval_params(import)
    end

    assert_response :unprocessable_entity
  end

  test "forbids approval for a viewer" do
    sign_in_with_role(:viewer)
    import = create_import(processed: true)

    assert_no_difference "Approval.count" do
      post approval_path, params: approval_params(import)
    end

    assert_response :forbidden
  end

  test "forbids approving another bucket's import" do
    sign_in_with_role(:admin)
    other_bucket = Bucket.create!(name: "Other")
    other_import = create_import(bucket: other_bucket, processed: true)

    assert_no_difference "Approval.count" do
      post approval_path, params: approval_params(other_import)
    end

    assert_response :forbidden
  end

  test "redirects guests to sign in without creating an approval" do
    import = create_import(processed: true)

    assert_no_difference "Approval.count" do
      post approval_path, params: approval_params(import)
    end

    assert_redirected_to new_session_path
  end

  test "returns not found when the approval identifier is missing" do
    sign_in_with_role(:admin)

    assert_no_difference "Approval.count" do
      post approval_path
    end

    assert_response :not_found
  end

  test "returns not found for an invalid approval identifier" do
    sign_in_with_role(:admin)

    assert_no_difference "Approval.count" do
      post approval_path, params: { approvable: "invalid" }
    end

    assert_response :not_found
  end

  test "returns not found for an identifier signed for another purpose" do
    sign_in_with_role(:admin)
    import = create_import(processed: true)

    assert_no_difference "Approval.count" do
      post approval_path,
        params: approval_params(import, purpose: "publication")
    end

    assert_response :not_found
  end

  test "returns not found when the identified import has been deleted" do
    sign_in_with_role(:admin)
    import = create_import
    submitted_params = approval_params(import)
    import.destroy!

    assert_no_difference "Approval.count" do
      post approval_path, params: submitted_params
    end

    assert_response :not_found
  end

  test "returns not found for a subject that does not support approval" do
    sign_in_with_role(:admin)

    assert_no_difference "Approval.count" do
      post approval_path, params: approval_params(@bucket)
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

  def approval_params(subject, purpose: "approval")
    {
      approvable: subject.to_sgid(for: purpose, expires_in: nil).to_s
    }
  end
end
