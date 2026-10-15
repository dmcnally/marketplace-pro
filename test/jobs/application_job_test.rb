require "test_helper"

class ApplicationJobTest < ActiveJob::TestCase
  include CsvImportTestHelper

  setup do
    @person = users(:two).person
    @bucket = buckets(:default)
    @other_person = users(:one).person
    @other_bucket = Bucket.create!(name: "Other")
  end

  test "attributes imported articles to the person who queued approval" do
    import = create_import

    Current.set(person: @person, bucket: @bucket) do
      import.approve!
    end

    Current.set(person: @other_person, bucket: @other_bucket) do
      perform_enqueued_jobs
    end

    assert_equal [ @person ] * 3, imported_articles.map(&:creator)
    assert_empty imported_articles(bucket: @other_bucket)
  end

  test "uses the current person when the approval job runs immediately" do
    import = create_import
    approval = Approval.create!(approvable: import, person: @other_person)

    Current.set(person: @person, bucket: @bucket) do
      Approvals::ProcessJob.perform_now(approval)
    end

    assert_equal [ @person ] * 3, imported_articles.map(&:creator)
  end

  test "keeps each queued approval's person and bucket separate" do
    import = create_import
    other_import = create_import(bucket: @other_bucket, created_by: @other_person)

    Current.set(person: @person, bucket: @bucket) do
      import.approve!
    end

    Current.set(person: @other_person, bucket: @other_bucket) do
      other_import.approve!
    end

    perform_enqueued_jobs

    assert_equal [ @person ] * 3, imported_articles.map(&:creator)
    assert_equal [ @other_person ] * 3, imported_articles(bucket: @other_bucket).map(&:creator)
  end

  test "restores the previous person and bucket after the job finishes" do
    import = create_import

    Current.set(person: @person, bucket: @bucket) do
      import.approve!
    end

    Current.set(person: @other_person, bucket: @other_bucket) do
      perform_enqueued_jobs

      assert import.reload.approved?
      assert_equal @other_person, Current.person
      assert_equal @other_bucket, Current.bucket
    end
  end

  test "restores the previous person and bucket if the job fails" do
    import = create_import

    Current.set(person: @person, bucket: @bucket) do
      import.approve!
    end

    import.source_file.attach(
      io: Rails.root.join("test/examples/rows_missing_headers.csv").open,
      filename: "rows_missing_headers.csv",
      content_type: "text/csv"
    )

    Current.set(person: @other_person, bucket: @other_bucket) do
      assert_raises(ArgumentError) { perform_enqueued_jobs }

      assert_equal @other_person, Current.person
      assert_equal @other_bucket, Current.bucket
    end
  end

  private

  def create_import(**attributes)
    create_csv_import(
      bucket: @bucket,
      created_by: @person,
      processed: true,
      **attributes
    )
  end

  def imported_articles(bucket: @bucket)
    bucket.recordings.articles.order(:id)
  end
end
