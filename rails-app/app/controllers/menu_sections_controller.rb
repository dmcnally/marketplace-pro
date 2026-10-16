class MenuSectionsController < ApplicationController
  include CatalogueFeedback
  layout "catalogue"
  before_action :authorize_menu
  rescue_from Recording::CatalogueEditing::StaleDraft, with: :stale_draft

  def new
    @draft = MenuSection::Draft.new(menu: menu, revision: menu.draft_revision)
  end

  def create
    @draft = MenuSection::Draft.new(section_params.merge(menu: menu, revision: params[:revision]))
    save_draft(:new)
  end

  def edit
    @draft = MenuSection::Draft.for(menu, section)
  end

  def update
    @draft = MenuSection::Draft.for(menu, section)
    @draft.assign_attributes(section_params.merge(revision: params[:revision]))
    save_draft(:edit)
  end

  def destroy
    Menu::Structure.new(menu).remove!(section, revision: params[:revision])
    redirect_to edit_admin_menu_path(menu), notice: "Section removed from the draft. Its history is preserved.", status: :see_other
  end

  private

  def menu = @menu ||= recordings.menus.find(params[:menu_id])
  def section = menu.children.menu_sections.where(id: menu.recordable.section_order).find(params[:id])

  def authorize_menu
    raise Authorization::Denied unless MenuPolicy.new(person: Current.person, bucket: Current.bucket).can_edit?(menu)
  end

  def section_params
    params.require(:menu_section).permit(:name, :description, :image, :remove_image, product_ids: []).to_h
  end

  def save_draft(template)
    if @draft.save
      redirect_to edit_admin_menu_path(menu), notice: "Section draft saved.", status: :see_other
    else
      render template, status: :unprocessable_entity
    end
  end

  def stale_draft
    render "catalogue/stale", locals: { reload_path: edit_admin_menu_path(menu) }, status: :conflict
  end
end
