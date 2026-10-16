class Products::CopiesController < ApplicationController
  include CatalogueFeedback
  layout "catalogue"
  before_action :authorize_source
  rescue_from Recording::CatalogueEditing::StaleDraft, with: :stale_draft

  def new
    @copy = Product::Copy.new(source: source, name: "#{source.recordable.name} copy", revision: source.draft_revision)
  end

  def create
    @copy = Product::Copy.new(source: source, name: params.require(:product_copy).permit(:name)[:name], revision: params[:revision])
    if @copy.save
      redirect_to edit_admin_product_path(@copy.recording), notice: "Product copied as an unpublished draft. All copied variants are unavailable; review their allergens before publishing.", status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def source
    @source ||= recordings.products.find(params[:product_id])
  end

  def authorize_source
    raise Authorization::Denied unless ProductPolicy.new(person: Current.person, bucket: Current.bucket).can_copy?(source)
  end

  def stale_draft
    render "catalogue/stale", locals: { reload_path: new_admin_product_copy_path(source) }, status: :conflict
  end
end
