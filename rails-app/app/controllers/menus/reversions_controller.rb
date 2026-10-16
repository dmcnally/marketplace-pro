class Menus::ReversionsController < ApplicationController
  include CatalogueFeedback
  layout "catalogue"
  before_action :prepare_reversion
  rescue_from Recording::CatalogueEditing::StaleDraft, with: :stale_review
  rescue_from Menu::Publication::Invalid, with: :invalid_reversion

  def new
  end

  def create
    @publication.revert!(token: params[:review_token])
    notice = "Menu draft reverted. Product content, publication status and live availability are unchanged. History is preserved."
    notice += " Archived references remain archived: #{@publication.archived_references.join(', ')}. Restore them separately." if @publication.archived_references.any?
    redirect_to edit_admin_menu_path(@recording), notice: notice, status: :see_other
  end

  private

  def prepare_reversion
    @recording = recordings.menus.find(params[:menu_id])
    policy = MenuPolicy.new(person: Current.person, bucket: Current.bucket)
    raise Authorization::Denied unless policy.can_revert?(@recording)

    @publication = Menu::Publication.new(@recording)
  end

  def stale_review
    render "catalogue/stale", locals: { reload_path: new_admin_menu_reversion_path(@recording) }, status: :conflict
  end

  def invalid_reversion(error)
    flash.now[:alert] = error.message
    render :new, status: :unprocessable_entity
  end
end
