module Permissible
  extend ActiveSupport::Concern

  def editable_by?(person)
    permission_policy_for(person).editable?
  end

  def deletable_by?(person)
    permission_policy_for(person).deletable?
  end

  def viewable_by?(person)
    permission_policy_for(person).viewable?
  end

  private

  def permission_policy_for(person)
    permission_policy_class.new(person:, recording: self)
  end

  def permission_policy_class
    "#{recordable_type}RecordingPolicy".safe_constantize || DefaultRecordingPolicy
  end
end
