class PublicationsActions < ActionsBase
  def toggle_for(publishable)
    return unless person_allowed_to?(:publish, publishable)

    view.render "publications/toggle", publishable:
  end
end
