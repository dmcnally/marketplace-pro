class Products::AllergenAssignmentsController < ApplicationController
  include CatalogueFeedback
  layout "catalogue"
  rescue_from Recording::CatalogueEditing::StaleDraft, with: :stale_draft

  def create
    product = recordings.products.find(params[:product_id])
    raise Authorization::Denied unless ProductPolicy.new(person: Current.person, bucket: Current.bucket).can_edit?(product)

    Product::VariantChanges.new(product).assign_allergen!(params[:allergen_id], remove: params[:operation] == "remove", revision: params[:revision])
    redirect_to edit_admin_product_path(product), notice: "Variant allergen assignments saved.", status: :see_other
  end

  private

  def stale_draft
    render "catalogue/stale", locals: { reload_path: admin_products_path }, status: :conflict
  end
end
