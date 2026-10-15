class MakeCsvImportsImportTypeRequired < ActiveRecord::Migration[8.1]
  def change
    change_column_null :csv_imports, :import_type, false
  end
end
