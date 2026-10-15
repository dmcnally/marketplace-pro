class CsvImportPolicy
  def initialize(person:, bucket:)
    @person = person
    @bucket = bucket
  end

  def can_create?
    bucket_admin?
  end

  def can_view?(csv_import = nil)
    bucket_admin? && (csv_import.nil? || csv_import.bucket == bucket)
  end

  def can_approve?(csv_import)
    bucket_admin? && csv_import.bucket == bucket
  end

  def can_delete?(csv_import)
    bucket_admin? && csv_import.bucket == bucket
  end

  private

  attr_reader :person, :bucket

  def bucket_admin?
    bucket.present? && person.admin_of?(bucket)
  end
end
