class Menus::SectionOrdersController < ApplicationController
  include CatalogueFeedback
  layout "catalogue"
  rescue_from Recording::CatalogueEditing::StaleDraft, with: :stale_draft

  def create
    menu = recordings.menus.find(params[:menu_id])
    raise Authorization::Denied unless MenuPolicy.new(person: Current.person, bucket: Current.bucket).can_edit?(menu)

    Menu::Structure.new(menu).reorder!(params.require(:positions).each_pair.sort_by { |id, position| position.to_i }.map(&:first), revision: params[:revision])
    redirect_to edit_admin_menu_path(menu), notice: "Section order saved.", status: :see_other
  rescue ArgumentError => error
    redirect_to edit_admin_menu_path(menu), alert: error.message, status: :see_other
  end

  private

  def stale_draft
    render "catalogue/stale", locals: { reload_path: admin_menus_path }, status: :conflict
  end
end
