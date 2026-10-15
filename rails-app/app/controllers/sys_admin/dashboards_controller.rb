class SysAdmin::DashboardsController < SysAdminController
  def show # rubocop:todo Controllers/MultipleInstanceVariables
    @bucket_count = Bucket.count
    @user_count = User.count
  end
end
