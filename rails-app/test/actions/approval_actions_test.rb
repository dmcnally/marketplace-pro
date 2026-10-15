require "test_helper"

class ApprovalActionsTest < ActionView::TestCase
  include CsvImportTestHelper
  include ActiveJob::TestHelper

  setup do
    view.extend(Rails.application.routes.url_helpers)
  end

  test "shows an approve button for a ready import when approval is allowed" do
    person = Current.person
    bucket = Current.bucket
    Membership.create!(person: person, bucket: bucket, role: :admin)
    import = create_csv_import(bucket: bucket, created_by: person, processed: true)

    actions = ApprovalActions.new(
      view: view,
      person: person,
      bucket: bucket
    )

    render html: actions.approve_button_for(import)

    assert_select 'button[type="submit"]',
      text: "Approve",
      count: 1
  end

  test "submits the selected import to the approval endpoint" do
    person = Current.person
    bucket = Current.bucket
    Membership.create!(person: person, bucket: bucket, role: :admin)
    import = create_csv_import(bucket: bucket, created_by: person, processed: true)

    actions = ApprovalActions.new(
      view: view,
      person: person,
      bucket: bucket
    )

    render html: actions.approve_button_for(import)

    assert_select 'form[action="/approval"][method="post"]', count: 1 do
      assert_select 'input[name="approvable"]', count: 1 do |inputs|
        submitted_import = GlobalID::Locator.locate_signed(
          inputs.first["value"],
          for: "approval"
        )

        assert_equal import, submitted_import
      end
    end
  end

  test "hides the approve button when approval is denied" do
    person = Current.person
    bucket = Current.bucket
    Membership.create!(person: person, bucket: bucket, role: :viewer)
    import = create_csv_import(bucket: bucket, created_by: person, processed: true)

    actions = ApprovalActions.new(
      view: view,
      person: person,
      bucket: bucket
    )

    assert_nil actions.approve_button_for(import)
  end

  test "hides the approve button for a subject that does not support approval" do
    person = Current.person
    bucket = Current.bucket
    Membership.create!(person: person, bucket: bucket, role: :admin)

    actions = ApprovalActions.new(
      view: view,
      person: person,
      bucket: bucket
    )

    assert_nil actions.approve_button_for(bucket)
  end

  test "hides the approve button before the import is ready" do
    person = Current.person
    bucket = Current.bucket
    Membership.create!(person: person, bucket: bucket, role: :admin)
    import = create_csv_import(bucket: bucket, created_by: person, processed: false)

    actions = ApprovalActions.new(
      view: view,
      person: person,
      bucket: bucket
    )

    assert_nil actions.approve_button_for(import)
  end

  test "hides the approve button after the import is approved" do
    person = Current.person
    bucket = Current.bucket
    Membership.create!(person: person, bucket: bucket, role: :admin)
    import = create_csv_import(bucket: bucket, created_by: person, processed: true)

    perform_enqueued_jobs do
      import.approve!
    end

    actions = ApprovalActions.new(
      view: view,
      person: person,
      bucket: bucket
    )

    assert_nil actions.approve_button_for(import.reload)
  end

  test "shows a disabled approving button while approval is in progress" do
    person = Current.person
    bucket = Current.bucket
    Membership.create!(person: person, bucket: bucket, role: :admin)
    import = create_csv_import(bucket: bucket, created_by: person, processed: true)
    import.approve!

    actions = ApprovalActions.new(
      view: view,
      person: person,
      bucket: bucket
    )

    render html: actions.approve_button_for(import.reload)

    assert_select 'button[type="button"][disabled]',
      text: "Approving",
      count: 1
    assert_select 'form[action="/approval"]', count: 0
  end

  test "hides approval controls when approval is in progress and permission is denied" do
    person = Current.person
    bucket = Current.bucket
    membership = Membership.create!(
      person: person,
      bucket: bucket,
      role: :admin
    )
    import = create_csv_import(bucket: bucket, created_by: person, processed: true)
    import.approve!
    membership.update!(role: :viewer)

    actions = ApprovalActions.new(
      view: view,
      person: person,
      bucket: bucket
    )

    assert_nil actions.approve_button_for(import.reload)
  end
end
