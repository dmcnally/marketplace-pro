class MenusController < ApplicationController
  include CatalogueFeedback
  layout "catalogue"
  before_action :authorize_management
  rescue_from Recording::CatalogueEditing::StaleDraft, with: :stale_draft

  def index
    @menus = recordings.menus.kept.includes(:recordable).map { |menu| Menu::Draft.for(menu) }
  end

  def show
    menu = recordings.menus.find(params[:id])
    @page = { recording: menu, events: menu.timeline_events.reorder(created_at: :desc, id: :desc).includes(:person, :subject, :subject_previous, :details) }
  end

  def new
    @draft = Menu::Draft.new(bucket: Current.bucket)
  end

  def create
    @draft = Menu::Draft.new(menu_params.merge(bucket: Current.bucket))
    save_draft(:new)
  end

  def edit
    @draft = Menu::Draft.for(editable_menu)
  end

  def update
    @draft = Menu::Draft.for(editable_menu)
    @draft.assign_attributes(menu_params.merge(revision: params[:revision]))
    save_draft(:edit)
  end

  private

  def policy = MenuPolicy.new(person: Current.person, bucket: Current.bucket)

  def authorize_management
    raise Authorization::Denied unless policy.can_create?
  end

  def editable_menu
    recordings.menus.find(params[:id]).tap { |menu| raise Authorization::Denied unless policy.can_edit?(menu) }
  end

  def menu_params
    params.require(:menu).permit(:name, :description, :image, :remove_image).to_h
  end

  def save_draft(template)
    if @draft.save
      redirect_to edit_admin_menu_path(@draft.recording), notice: "Menu draft saved.", status: :see_other
    else
      render template, status: :unprocessable_entity
    end
  end

  def stale_draft
    render "catalogue/stale", locals: { reload_path: admin_menus_path }, status: :conflict
  end
end
