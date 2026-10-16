class Catalogue::AvailabilitiesController < ApplicationController
  layout "staff"
  before_action :prepare_availability
  rescue_from Authorization::Denied, with: :availability_denied

  def create
    change_availability(true)
  end

  def destroy
    change_availability(false)
  end

  private

  def prepare_availability
    @availability = Catalogue::Availability.new(bucket: Current.bucket, person: Current.person)
    @policy = AvailabilityPolicy.new(availability: @availability)
    raise Authorization::Denied unless @policy.can_view?
  end

  def change_availability(available)
    recording = recordings.where(recordable_type: %w[Product Variant]).find(params[:recording_id])
    if recording.product?
      raise Authorization::Denied unless @policy.can_change_product?(recording)

      @availability.set_product!(recording, available: available)
    else
      raise Authorization::Denied unless @policy.can_change_variant?(recording)

      @availability.set_variant!(recording, available: available)
    end
    respond_with_overview("Availability updated.", error: false, status: :ok)
  end

  def availability_denied
    return head :forbidden unless @policy&.can_view?

    respond_with_overview("Availability could not be changed. This item is no longer eligible on the live menu. Review the current menu below.", error: true, status: :forbidden)
  end

  def respond_with_overview(message, error:, status:)
    @page = { overview: Catalogue::Overview.new(Current.bucket), message: message, error: error }
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("live-overview", partial: "catalogue/overviews/content", locals: @page), status: status }
      format.html do
        if error
          render "catalogue/overviews/show", status: status
        else
          redirect_to overview_path, notice: message, status: :see_other
        end
      end
    end
  end
end
