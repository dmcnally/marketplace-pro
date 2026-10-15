class ArticlesActions < ActionsBase
  def new_link(label: "New Article")
    return unless person_allowed_to?(:create, Article)

    view.link_to label, view.new_article_path, class: "btn btn--primary"
  end

  def edit_link_for(article)
    return unless person_allowed_to?(:edit, article)

    view.link_to "Edit", view.edit_article_path(article), class: "btn btn--primary"
  end

  def delete_button_for(article)
    return unless person_allowed_to?(:delete, article)

    view.link_to "Delete", view.article_path(article), class: "btn btn--danger", data: { turbo_method: :delete, turbo_confirm: "Are you sure you want to delete this article?" }
  end
end
