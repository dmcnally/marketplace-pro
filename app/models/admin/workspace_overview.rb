class Admin::WorkspaceOverview
  attr_reader :bucket, :person

  def initialize(bucket:, person:)
    @bucket = bucket
    @person = person
  end

  def first_name
    person.person_card.first_name.presence || "there"
  end

  def initials
    person.person_card.name.split.map(&:first).first(2).join.upcase.presence || "ME"
  end

  def articles
    bucket.recordings.kept.articles
  end

  def published_count
    articles.published.count
  end

  def draft_count
    articles.unpublished.count
  end

  def member_count
    bucket.memberships.count
  end

  def new_member_count
    bucket.memberships.where(created_at: 30.days.ago..).count
  end

  def invitations
    @invitations ||= bucket.membership_invites.order(created_at: :desc).select(&:active?)
  end

  def memberships
    @memberships ||= bucket.memberships.includes(person: [ :user, { recording: :recordable } ]).order(:id).limit(3)
  end

  def recent_events
    @recent_events ||= bucket.events.includes(:subject, person: { recording: :recordable }).order(created_at: :desc).limit(3)
  end

  def publishing_days
    @publishing_days ||= begin
      start = Date.current.beginning_of_week
      dates = publication_events.where(created_at: start.beginning_of_day...start.next_week.beginning_of_day).pluck(:created_at).map { |time| time.in_time_zone.to_date }.tally
      (start..start + 6).map { |date| [ date, dates.fetch(date, 0) ] }
    end
  end

  def published_this_week
    publishing_days.sum(&:last)
  end

  def published_this_month
    publication_events.where(created_at: Time.current.beginning_of_month..).count
  end

  private

  def publication_events
    bucket.events.where(subject_type: "Article", action: "published")
  end
end
