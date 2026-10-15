class Buckets::SwitchController < ApplicationController
  skip_before_action :require_current_bucket
  before_action :set_bucket

  def create
    return head :forbidden unless Current.person.switchable_content_bucket?(@bucket)

    session[:bucket_id] = @bucket.id
    redirect_to root_path, notice: "Switched to #{@bucket.name}."
  end

  def destroy
    return head :forbidden unless Current.person.sys_admin?

    session.delete(:bucket_id)
    redirect_to sys_admin_root_path, notice: "Exited bucket."
  end

  private

  def set_bucket
    @bucket = Bucket.find(params[:bucket_id])
  end
end
