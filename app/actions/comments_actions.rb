class CommentsActions < ActionsBase
  def new_form_for(parent_recording)
    return view.render("comments/sign_in_required") if parent_recording.commentable? && person.guest?
    return unless person_allowed_to?(:comment_on, parent_recording)

    view.render "comments/form", parent_recording:, comment: Comment.new
  end
end
