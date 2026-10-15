class ActionsBase
  def initialize(view:, person:, bucket:, permissions: nil)
    @view = view
    @person = person
    @bucket = bucket
    @permissions = permissions || PersonAllowedTo.new(person:, bucket:)
  end

  private

  attr_reader :view, :person, :bucket, :permissions

  def person_allowed_to?(action, subject)
    permissions.allowed?(action, subject)
  end
end
