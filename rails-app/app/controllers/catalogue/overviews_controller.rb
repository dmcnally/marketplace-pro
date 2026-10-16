class Catalogue::OverviewsController < ApplicationController
  layout "staff"

  def show
    availability = Catalogue::Availability.new(bucket: Current.bucket, person: Current.person)
    raise Authorization::Denied unless AvailabilityPolicy.new(availability: availability).can_view?

    @page = { overview: Catalogue::Overview.new(Current.bucket), message: nil, error: false }
  end
end
