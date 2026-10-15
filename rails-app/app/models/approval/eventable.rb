module Approval::Eventable
  extend ActiveSupport::Concern

  include ::Eventable

  def current_subject = approvable
  def subject_changed? = saved_change_to_status?
  def action_for_create = status
  def action_for_update = status
  def previous_subject_type = nil
  def previous_subject_id = nil
  def current_person_id = person_id
end
