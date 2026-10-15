class Approval < ApplicationRecord
  include Eventable

  belongs_to :approvable, polymorphic: true
  belongs_to :person, optional: true

  delegate :bucket, to: :approvable

  attr_writer :updates

  def creator
    person
  end

  def updates
    @updates || NullUpdates::INSTANCE
  end
end
