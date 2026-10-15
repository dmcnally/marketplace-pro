module Admin::CsvImportsHelper
  def csv_import_filter
    @csv_import_filter ||= begin
      filter = params[:filter].presence || "all"
      raise ActiveRecord::RecordNotFound unless %w[all errors valid].include?(filter)

      filter
    end
  end
end
