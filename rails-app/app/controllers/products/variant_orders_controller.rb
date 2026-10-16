class Products::VariantOrdersController < ApplicationController
  include CatalogueFeedback
  layout "catalogue"
  rescue_from Recording::CatalogueEditing::StaleDraft, with: :stale_draft

  def create
    product = recordings.products.find(params[:product_id])
    raise Authorization::Denied unless ProductPolicy.new(person: Current.person, bucket: Current.bucket).can_edit?(product)

    Product::VariantChanges.new(product).reorder!(params.require(:positions).each_pair.sort_by { |id, position| position.to_i }.map(&:first), revision: params[:revision])
    redirect_to edit_admin_product_path(product), notice: "Variant order saved. Publish the product to update the live order.", status: :see_other
  rescue ArgumentError => error
    redirect_to edit_admin_product_path(product), alert: error.message, status: :see_other
  end

  private

  def stale_draft
    render "catalogue/stale", locals: { reload_path: admin_products_path }, status: :conflict
  end
end
