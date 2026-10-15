class Comment < ApplicationRecord
  include Recordable

  validates :body, presence: true

  def before_discard(recording)
    recording.children.kept.find_each(&:discard!)
  end
end
