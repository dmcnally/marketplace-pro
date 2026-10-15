module AdminHelper
  def admin_import_actions
    @admin_import_actions ||= Admin::ImportActions.new(view: self, person: Current.person, bucket: Current.bucket)
  end

  def admin_csv_import_actions
    @admin_csv_import_actions ||= Admin::CsvImportActions.new(
      view: self, person: Current.person, bucket: Current.bucket, selected_filter: csv_import_filter
    )
  end

  def admin_actions
    @admin_actions ||= Admin::Actions.new(view: self, person: Current.person, bucket: Current.bucket)
  end

  def admin_sidebar_actions
    @admin_sidebar_actions ||= Admin::SidebarActions.new(view: self, person: Current.person, bucket: Current.bucket)
  end

  def admin_invitation_actions
    @admin_invitation_actions ||= Admin::InvitationActions.new(view: self, person: Current.person, bucket: Current.bucket)
  end
end
