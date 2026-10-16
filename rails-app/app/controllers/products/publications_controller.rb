class Products::PublicationsController < ApplicationController
  include CatalogueFeedback
  layout "catalogue"
  before_action :prepare_publication
  rescue_from Recording::CatalogueEditing::StaleDraft, with: :stale_review
  rescue_from Product::Publication::Invalid, with: :invalid_publication

  def new
  end

  def create
    @publication.publish!(token: params[:review_token])
    redirect_to edit_admin_product_path(@recording), notice: "Product and variants published.", status: :see_other
  end

  def destroy
    raise Authorization::Denied unless @policy.can_unpublish?(@recording)

    @publication.unpublish!(token: params[:review_token])
    redirect_to edit_admin_product_path(@recording), notice: "Product unpublished.", status: :see_other
  end

  private

  def prepare_publication
    @recording = recordings.products.find(params[:product_id])
    @policy = ProductPolicy.new(person: Current.person, bucket: Current.bucket)
    raise Authorization::Denied unless @policy.can_publish?(@recording)

    @publication = Product::Publication.new(@recording)
  end

  def stale_review
    render "catalogue/stale", locals: { reload_path: new_admin_product_publication_path(@recording) }, status: :conflict
  end

  def invalid_publication(error)
    flash.now[:alert] = error.message
    render :new, status: :unprocessable_entity
  end
end
