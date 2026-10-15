require "test_helper"

class Admin::WorkspaceOverviewTest < ActiveSupport::TestCase
  test "article counts exclude other workspaces and discarded articles" do
    bucket = buckets(:default)
    other = Bucket.create!(name: "Other workspace")
    published = bucket.recordings.create!(recordable: Article.new(title: "Published"))
    published.publish!
    bucket.recordings.create!(recordable: Article.new(title: "Draft"))
    discarded = bucket.recordings.create!(recordable: Article.new(title: "Discarded"))
    discarded.discard!
    other.recordings.create!(recordable: Article.new(title: "Private")).publish!

    overview = Admin::WorkspaceOverview.new(bucket: bucket, person: people(:two))

    assert_equal 1, overview.published_count
    assert_equal 1, overview.draft_count
    assert_equal 1, overview.published_this_week
    assert_equal 7, overview.publishing_days.size
    assert overview.recent_events.all? { |event| event.bucket_id == bucket.id }
  end

  test "publishing chart includes zero days and excludes previous weeks" do
    travel_to Time.zone.local(2026, 10, 14, 12) do
      bucket = buckets(:default)
      article = bucket.recordings.create!(recordable: Article.new(title: "This week"))
      article.publish!
      bucket.events.create!(eventable: article, subject: article.recordable, action: "published", created_at: 8.days.ago)
      overview = Admin::WorkspaceOverview.new(bucket: bucket, person: people(:two))

      assert_equal 1, overview.published_this_week
      assert_equal [ 0, 0, 1, 0, 0, 0, 0 ], overview.publishing_days.map(&:last)
    end
  end
end
