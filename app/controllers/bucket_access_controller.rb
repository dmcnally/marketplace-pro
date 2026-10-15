class BucketAccessController < ApplicationController
  skip_before_action :require_current_bucket

  def show
  end
end
