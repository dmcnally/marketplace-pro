class Admin::Actions < ActionsBase
  def header_link
    return unless person.admin_of?(bucket)

    view.link_to "Admin", view.admin_root_path, class: "site-header__link"
  end
end
