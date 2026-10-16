class MenuSections::ProductOrdersController < ApplicationController
  include CatalogueFeedback
  layout "catalogue"
  rescue_from Recording::CatalogueEditing::StaleDraft, with: :stale_draft

  def create
    menu = recordings.menus.find(params[:menu_id])
    raise Authorization::Denied unless MenuPolicy.new(person: Current.person, bucket: Current.bucket).can_edit?(menu)

    section = menu.children.menu_sections.where(id: menu.recordable.section_order).find(params[:section_id])
    MenuSection::Placements.new(menu, section).reorder!(params.require(:positions).each_pair.sort_by { |id, position| position.to_i }.map(&:first), revision: params[:revision])
    redirect_to edit_admin_menu_path(menu), notice: "Product order saved for this section.", status: :see_other
  rescue ArgumentError => error
    redirect_to edit_admin_menu_path(menu), alert: error.message, status: :see_other
  end

  private

  def stale_draft
    render "catalogue/stale", locals: { reload_path: admin_menus_path }, status: :conflict
  end
end
