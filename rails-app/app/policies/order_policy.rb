class OrderPolicy
  def initialize(person:, bucket:)
    @person = person
    @bucket = bucket
  end

  def can_view?
    @bucket.present? && @person.viewer_of?(@bucket)
  end
end
