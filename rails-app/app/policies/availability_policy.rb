class AvailabilityPolicy
  def initialize(availability:)
    @availability = availability
  end

  delegate :can_view?, :can_change_product?, :can_change_variant?, to: :@availability
end
