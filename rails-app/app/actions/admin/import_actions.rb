class Admin::ImportActions < ActionsBase
  def new_import
    return unless person_allowed_to?(:create, CsvImport)

    view.link_to "New Import", view.new_admin_csv_import_path, class: "btn btn--primary"
  end

  def index_back_link
    return unless person_allowed_to?(:view, CsvImport)

    view.link_to "Back to Imports", view.admin_csv_imports_path, class: "back-link"
  end

  def type_link_for(import_type, selected_type: nil)
    return unless person_allowed_to?(:create, CsvImport)
    return unless Imports::Csv::Types.keys.include?(import_type)

    selected = selected_type == import_type
    view.link_to import_type.humanize,
      view.new_admin_csv_import_path(import_type:),
      class: selected ? "btn btn--primary" : "btn btn--secondary",
      aria: { current: selected ? "page" : nil }
  end

  def form_cancel_link
    view.link_to "Cancel", view.admin_csv_imports_path, class: "btn btn--secondary"
  end
end
