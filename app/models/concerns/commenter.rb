module Commenter
  extend ActiveSupport::Concern

  def comments
    return self.class.none unless recordable.commentable?

    children.where(recordable_type: "Comment")
  end

  def commentable?
    recordable.commentable?
  end
end
