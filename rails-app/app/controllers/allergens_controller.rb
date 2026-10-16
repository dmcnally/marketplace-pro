class AllergensController < ApplicationController
  include CatalogueFeedback
  layout "catalogue"
  before_action :authorize_management
  before_action :set_recording, only: %i[show edit update]
  rescue_from Recording::CatalogueEditing::StaleDraft, with: :stale_draft

  def index
    @page = { archived: params[:archived] == "1" }
    @page[:recordings] = allergen_recordings.where(discarded_at: @page[:archived] ? ..Time.current : nil).includes(:recordable).order(:id)
  end

  def show
    @page = { recording: @recording, events: @recording.events.includes(:person, :subject, :subject_previous).order(created_at: :desc, id: :desc) }
  end

  def new
    @recording = allergen_recordings.build(recordable: Allergen.new)
  end

  def create
    @recording = allergen_recordings.build(recordable: Allergen.new(allergen_params))
    if @recording.save
      redirect_to admin_allergens_path, notice: "Allergen created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    raise Authorization::Denied unless allergen_policy.can_edit?(@recording)
  end

  def update
    raise Authorization::Denied unless allergen_policy.can_edit?(@recording)

    @recording.revise_content!(allergen_params, revision: params[:revision])
    redirect_to admin_allergens_path, notice: "Allergen saved.", status: :see_other
  rescue ActiveRecord::RecordInvalid
    render :edit, status: :unprocessable_entity
  end

  private

  def allergen_recordings
    recordings.allergens
  end

  def set_recording
    @recording = allergen_recordings.find(params[:id])
  end

  def allergen_params
    params.require(:allergen).permit(:name, :description)
  end

  def allergen_policy
    AllergenPolicy.new(person: Current.person, bucket: Current.bucket)
  end

  def authorize_management
    raise Authorization::Denied unless allergen_policy.can_create?
  end

  def stale_draft
    render "catalogue/stale", locals: { reload_path: admin_allergens_path }, status: :conflict
  end
end
