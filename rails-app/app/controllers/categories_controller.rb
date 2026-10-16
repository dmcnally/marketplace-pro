class CategoriesController < ApplicationController
  layout "catalogue"
  before_action :authorize_management
  before_action :set_recording, only: %i[show edit update]
  rescue_from Recording::CatalogueEditing::StaleDraft, with: :stale_draft

  def index
    @page = { archived: params[:archived] == "1" }
    @page[:recordings] = category_recordings.where(discarded_at: @page[:archived] ? ..Time.current : nil).includes(:recordable).order(:id)
  end

  def show
    @page = { recording: @recording, events: @recording.events.includes(:person, :subject, :subject_previous).order(created_at: :desc, id: :desc) }
  end

  def new
    @recording = category_recordings.build(recordable: Category.new)
  end

  def create
    @recording = category_recordings.build(recordable: Category.new(category_params))
    if @recording.save
      redirect_to admin_categories_path, notice: "Category created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    raise Authorization::Denied unless category_policy.can_edit?(@recording)
  end

  def update
    raise Authorization::Denied unless category_policy.can_edit?(@recording)

    @recording.revise_content!(category_params, revision: params[:revision])
    redirect_to admin_categories_path, notice: "Category saved.", status: :see_other
  rescue ActiveRecord::RecordInvalid
    render :edit, status: :unprocessable_entity
  end

  private

  def category_recordings
    recordings.categories
  end

  def set_recording
    @recording = category_recordings.find(params[:id])
  end

  def category_params
    params.require(:category).permit(:name, :description)
  end

  def category_policy
    CategoryPolicy.new(person: Current.person, bucket: Current.bucket)
  end

  def authorize_management
    raise Authorization::Denied unless category_policy.can_create?
  end

  def stale_draft
    render "catalogue/stale", status: :conflict
  end
end
