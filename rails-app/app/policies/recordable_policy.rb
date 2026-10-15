class RecordablePolicy
  def initialize(person:, bucket:)
    @person = person
    @bucket = bucket
  end

  private

  attr_reader :person, :bucket

  def assert_recordable!(recording)
    return if recording.recordable_type == expected_recordable_type

    raise ArgumentError, "#{self.class.name} cannot authorize #{recording.recordable_type}"
  end

  def bucket_admin?
    person.admin_of?(bucket)
  end

  def expected_recordable_type
    self.class.name.delete_suffix("Policy")
  end
end
