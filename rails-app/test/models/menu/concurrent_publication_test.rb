require "test_helper"
require_relative "../../test_helpers/catalogue_test_helper"
require "timeout"

class Menu::ConcurrentPublicationTest < Minitest::Test
  include CatalogueTestHelper

  def test_simultaneous_confirmations_publish_one_menu_and_reject_the_stale_review
    Current.reset
    bucket = Bucket.create!(name: "Concurrent menus #{SecureRandom.hex(6)}")
    Current.bucket = bucket
    product = create_catalogue_product(bucket: bucket)
    publication = Product::Publication.new(product)
    publication.publish!(token: publication.review_token)
    menus = 2.times.map do |index|
      menu = create_catalogue_menu(bucket: bucket, name: "Menu #{index}")
      add_menu_section(menu, product_ids: [ product.id ])
      menu.reload
    end
    tokens = menus.map { |menu| Menu::Publication.new(menu).review_token }
    ready = Queue.new
    start = Queue.new
    results = Queue.new
    threads = menus.each_with_index.map do |menu, index|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          candidate = Menu::Publication.new(Recording.find(menu.id))
          ready << true
          start.pop
          begin
            candidate.publish!(token: tokens[index])
            results << :published
          rescue Recording::CatalogueEditing::StaleDraft
            results << :stale
          rescue => error
            results << error
          ensure
            Current.reset
          end
        end
      end
    end
    Timeout.timeout(10) do
      2.times { ready.pop }
      2.times { start << true }
      threads.each(&:join)
    end
    outcomes = 2.times.map { results.pop }
    assert_equal [ :published, :stale ], outcomes.sort_by(&:to_s), outcomes.inspect
    assert_equal 1, Catalogue::Release.active.where(bucket: bucket, kind: "Menu").count
    assert_equal 1, Catalogue::Snapshot.where(recording: menus).count
    assert_equal 1, bucket.events.where(action: "published", subject_type: "Menu").count
  ensure
    threads&.each { |thread| thread.kill if thread.alive? }
    cleanup_bucket(bucket) if bucket&.persisted?
    Current.reset
  end

  private

  def cleanup_bucket(bucket)
    recordings = Recording.where(bucket_id: bucket.id)
    events = Event.where(bucket_id: bucket.id)
    content = events.pluck(:subject_type, :subject_id).group_by(&:first)
    Event::Detail.where(event_id: events.select(:id)).delete_all
    Catalogue::Release.where(bucket: bucket).delete_all
    Catalogue::Snapshot.where(recording_id: recordings.select(:id)).delete_all
    VariantAvailability.where(recording_id: recordings.select(:id)).delete_all
    events.delete_all
    recordings.delete_all
    content.each { |type, rows| type.constantize.where(id: rows.map(&:last)).delete_all }
    Bucket.where(id: bucket.id).delete_all
  end
end
