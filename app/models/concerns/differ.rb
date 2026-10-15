module Differ
  extend ActiveSupport::Concern

  def diffable?
    recordable.diffable?
  end

  def previous_diff
    RecordableDiff.previous(self)
  end
end
