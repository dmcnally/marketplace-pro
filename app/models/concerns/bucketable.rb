module Bucketable
  extend ActiveSupport::Concern

  included do
    belongs_to :bucket

    before_validation :set_bucket, on: :create
  end

  private

  def set_bucket
    return if bucket.present?

    if respond_to?(:parent) && parent&.bucket
      self.bucket = parent.bucket
    else
      raise "Bucket must be set explicitly or via parent"
    end
  end
end
