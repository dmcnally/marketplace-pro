class Admin::CsvImportActions < ActionsBase
  def initialize(view:, person:, bucket:, selected_filter:, permissions: nil)
    super(view:, person:, bucket:, permissions:)
    @selected_filter = selected_filter
  end

  def link_to_all_records(import)
    return unless person_allowed_to?(:view, CsvImport)

    view.link_to "All records", view.admin_csv_import_path(import), link_options("all")
  end

  def link_to_errors(import)
    return unless person_allowed_to?(:view, CsvImport)

    view.link_to "Errors", view.admin_csv_import_path(import, filter: "errors"), link_options("errors")
  end

  def link_to_valid_records(import)
    return unless person_allowed_to?(:view, CsvImport)

    view.link_to "Valid", view.admin_csv_import_path(import, filter: "valid"), link_options("valid")
  end

  private

  def link_options(filter)
    selected = @selected_filter == filter
    {
      class: selected ? "btn btn--primary" : "btn btn--secondary",
      aria: { current: selected ? "page" : nil }
    }
  end
end
