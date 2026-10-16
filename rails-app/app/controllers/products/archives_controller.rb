class Products::ArchivesController < ApplicationController
  include CatalogueFeedback
  layout "catalogue"
  before_action :authorize_management
  rescue_from Recording::CatalogueEditing::StaleDraft, with: :stale_draft

  def index
    @page = { products: recordings.products.discarded.includes(:recordable), variants: recordings.variants.discarded.includes(:recordable, parent: :recordable) }
  end

  def new
    @recording = archived_subject
    raise Authorization::Denied unless policy.can_archive?(@recording)
  end

  def create
    recording = archived_subject
    raise Authorization::Denied unless policy.can_archive?(recording)

    recording.archive_content!(revision: params[:revision])
    redirect_to admin_archived_products_path, notice: "Product archived. All variants are unavailable; published versions and history are preserved.", status: :see_other
  end

  def destroy
    recording = archived_subject
    raise Authorization::Denied unless policy.can_restore?(recording)

    recording.restore_content!(revision: params[:revision])
    redirect_to edit_admin_product_path(recording), notice: "Product restored; all variants remain unavailable.", status: :see_other
  end

  private

  def archived_subject = recordings.products.find(params[:product_id])
  def policy = ProductPolicy.new(person: Current.person, bucket: Current.bucket)

  def authorize_management
    raise Authorization::Denied unless policy.can_create?
  end

  def stale_draft
    render "catalogue/stale", locals: { reload_path: admin_products_path }, status: :conflict
  end
end
