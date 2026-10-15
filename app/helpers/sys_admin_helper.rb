module SysAdminHelper
  def sys_admin_bucket_actions
    @sys_admin_bucket_actions ||= SysAdmin::BucketActions.new(view: self, person: Current.person)
  end

  def sys_admin_user_actions
    @sys_admin_user_actions ||= SysAdmin::UserActions.new(view: self, person: Current.person)
  end

  def sys_admin_actions
    @sys_admin_actions ||= SysAdmin::Actions.new(view: self, person: Current.person, bucket: Current.bucket)
  end

  def sys_admin_sidebar_actions
    @sys_admin_sidebar_actions ||= SysAdmin::SidebarActions.new(view: self, person: Current.person, bucket: Current.bucket)
  end
end
