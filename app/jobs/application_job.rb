class ApplicationJob < ActiveJob::Base
  before_enqueue :capture_current_context
  around_perform :with_current_context

  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  def serialize
    super.merge("current_context" => current_context)
  end

  def deserialize(job_data)
    super
    self.current_context = job_data["current_context"]
  end

  private

  attr_accessor :current_context

  def capture_current_context
    self.current_context = serialized_current_context
  end

  def with_current_context
    context = current_context || serialized_current_context

    Current.set(
      person: locate_current_record(context["person"]),
      bucket: locate_current_record(context["bucket"])
    ) { yield }
  end

  def serialized_current_context
    {
      "person" => Current.person&.to_global_id&.to_s,
      "bucket" => Current.bucket&.to_global_id&.to_s
    }
  end

  def locate_current_record(global_id)
    GlobalID::Locator.locate(global_id) if global_id
  end
end
