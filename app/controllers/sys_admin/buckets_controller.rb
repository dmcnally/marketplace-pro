class SysAdmin::BucketsController < SysAdminController
  before_action :set_bucket, only: [ :show, :edit, :update ]

  def index
    @buckets = Bucket.order(:name)
  end

  def show
  end

  def new
    @bucket = Bucket.new
  end

  def create
    @bucket = Bucket.new(bucket_params)

    if @bucket.save
      redirect_to sys_admin_buckets_path, notice: "Bucket was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @bucket.update(bucket_params)
      redirect_to sys_admin_buckets_path, notice: "Bucket was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_bucket
    @bucket = Bucket.find(params[:id])
  end

  def bucket_params
    params.require(:bucket).permit(:name)
  end
end
