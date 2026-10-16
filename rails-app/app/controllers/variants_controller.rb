class VariantsController < ApplicationController
  include CatalogueFeedback
  layout "catalogue"
  before_action :authorize_product
  rescue_from Recording::CatalogueEditing::StaleDraft, with: :stale_draft

  def new
    @draft = Product::VariantDraft.new(product: product, source_id: product.children.variants.kept.where(id: product.recordable.variant_order).order(:id).first&.id, revision: product.draft_revision)
  end

  def create
    @draft = Product::VariantDraft.new(variant_params.merge(product: product, revision: params[:revision]))
    save_draft(:new)
  end

  def edit
    @draft = Product::VariantDraft.for(product, product.children.variants.kept.where(id: product.recordable.variant_order).find(params[:id]))
  end

  def update
    @draft = Product::VariantDraft.for(product, product.children.variants.kept.where(id: product.recordable.variant_order).find(params[:id]))
    @draft.assign_attributes(variant_params.merge(revision: params[:revision]))
    save_draft(:edit)
  end

  private

  def product
    @product ||= recordings.products.find(params[:product_id])
  end

  def authorize_product
    raise Authorization::Denied unless ProductPolicy.new(person: Current.person, bucket: Current.bucket).can_edit?(product)
  end

  def variant_params
    params.require(:variant).permit(:name, :price, :source_id, allergen_ids: []).to_h
  end

  def save_draft(template)
    if @draft.save
      redirect_to edit_admin_product_path(product), notice: "Variant saved. Review its allergens before publishing.", status: :see_other
    else
      render template, status: :unprocessable_entity
    end
  end

  def stale_draft
    render "catalogue/stale", locals: { reload_path: edit_admin_product_path(product) }, status: :conflict
  end
end
