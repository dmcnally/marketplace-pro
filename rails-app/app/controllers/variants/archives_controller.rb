class Variants::ArchivesController < ApplicationController
  include CatalogueFeedback
  layout "catalogue"
  before_action :prepare_variant
  rescue_from Recording::CatalogueEditing::StaleDraft, with: :stale_draft

  def new
    raise Authorization::Denied unless policy.can_archive_variant?(@product, @variant)
  end

  def create
    raise Authorization::Denied unless policy.can_archive_variant?(@product, @variant)

    @variant.archive_content!(revision: params[:revision])
    redirect_to edit_admin_product_path(@product), notice: "Variant archived and unavailable. Other variants are unchanged.", status: :see_other
  end

  def destroy
    raise Authorization::Denied unless policy.can_restore_variant?(@product, @variant)

    @variant.restore_content!(revision: params[:revision])
    redirect_to admin_archived_products_path, notice: "Variant restored unavailable. It stays hidden if its product is archived or it is absent from the published version.", status: :see_other
  end

  private

  def prepare_variant
    @product = recordings.products.find(params[:product_id])
    @variant = @product.children.variants.find(params[:variant_id])
  end

  def policy = ProductPolicy.new(person: Current.person, bucket: Current.bucket)

  def stale_draft
    render "catalogue/stale", locals: { reload_path: admin_products_path }, status: :conflict
  end
end
