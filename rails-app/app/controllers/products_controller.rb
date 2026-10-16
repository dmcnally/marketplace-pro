class ProductsController < ApplicationController
  include CatalogueFeedback
  layout "catalogue"
  before_action :authorize_management
  rescue_from Recording::CatalogueEditing::StaleDraft, with: :stale_draft

  def index
    @catalogue = Product::Catalogue.new(bucket: Current.bucket, query: params[:q], category_id: params[:category_id], publication_state: params[:publication_state])
  end

  def show
    recording = product_recordings.find(params[:id])
    @page = { recording: recording, events: recording.timeline_events.includes(:person, :subject, :subject_previous, :details) }
  end

  def new
    @draft = Product::Draft.new(bucket: Current.bucket, variant_name: "Default")
  end

  def create
    @draft = Product::Draft.new(product_params.merge(bucket: Current.bucket))
    if @draft.save
      redirect_to edit_admin_product_path(@draft.recording), notice: "Product created. Review the first variant’s allergens; it starts unavailable."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @draft = Product::Draft.for(editable_product)
  end

  def update
    @draft = Product::Draft.for(editable_product)
    @draft.assign_attributes(product_params.merge(revision: params[:revision]))
    if @draft.save
      redirect_to edit_admin_product_path(@draft.recording), notice: "Product draft saved.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def product_recordings = recordings.products

  def editable_product
    product_recordings.find(params[:id]).tap do |recording|
      raise Authorization::Denied unless policy.can_edit?(recording)
    end
  end

  def policy = ProductPolicy.new(person: Current.person, bucket: Current.bucket)

  def authorize_management
    raise Authorization::Denied unless policy.can_create?
  end

  def product_params
    params.require(:product).permit(:name, :description, :image, :remove_image, :variant_name, :price, category_ids: []).to_h
  end

  def stale_draft
    render "catalogue/stale", locals: { reload_path: admin_products_path }, status: :conflict
  end
end
