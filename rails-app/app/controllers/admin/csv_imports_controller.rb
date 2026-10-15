class Admin::CsvImportsController < ApplicationController
  layout "management"

  before_action :set_import, only: [ :show, :destroy ]

  def index
    person_allowed_to!(:view, CsvImport)
    @imports = Current.bucket.csv_imports.includes(:created_by).order(created_at: :desc)
  end

  def show
    person_allowed_to!(:view, @import)
    raise ActiveRecord::RecordNotFound unless %w[all errors valid].include?(params[:filter].presence || "all")
  end

  def new
    person_allowed_to!(:create, CsvImport)
    import_type = params[:import_type].presence
    raise ActiveRecord::RecordNotFound if import_type && !Imports::Csv::Types.keys.include?(import_type)

    @import = CsvImport.new(import_type:)
  end

  def create
    person_allowed_to!(:create, CsvImport)
    @import = Current.bucket.csv_imports.build(csv_import_params.merge(created_by: Current.person))

    if @import.save
      Import::ProcessFileJob.perform_later(@import)
      redirect_to admin_csv_import_path(@import), notice: "CSV uploaded"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    person_allowed_to!(:delete, @import)
    @import.destroy!
    redirect_to admin_csv_imports_path, notice: "Import deleted", status: :see_other
  end

  private

  def set_import
    @import = Current.bucket.csv_imports.find(params[:id])
  end

  def csv_import_params
    params.require(:csv_import).permit(:import_type, :source_file)
  end
end
