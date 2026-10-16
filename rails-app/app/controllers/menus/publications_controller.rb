class Menus::PublicationsController < ApplicationController
  include CatalogueFeedback
  layout "catalogue"
  before_action :prepare_publication
  rescue_from Recording::CatalogueEditing::StaleDraft, with: :stale_review
  rescue_from Menu::Publication::Invalid, with: :invalid_publication

  def new
    if params[:intent] == "unpublish"
      raise Authorization::Denied unless @policy.can_unpublish?(@recording)

      render :unpublish
    end
  end

  def create
    @publication.publish!(token: params[:review_token])
    redirect_to edit_admin_menu_path(@recording), notice: "Menu published. It is now the only live menu in this workspace.", status: :see_other
  end

  def destroy
    raise Authorization::Denied unless @policy.can_unpublish?(@recording)

    @publication.unpublish!(token: params[:review_token])
    redirect_to edit_admin_menu_path(@recording), notice: "Menu unpublished. There is no live menu.", status: :see_other
  end

  private

  def prepare_publication
    @recording = recordings.menus.find(params[:menu_id])
    @policy = MenuPolicy.new(person: Current.person, bucket: Current.bucket)
    raise Authorization::Denied unless @policy.can_publish?(@recording)

    @publication = Menu::Publication.new(@recording)
  end

  def stale_review
    render "catalogue/stale", locals: { reload_path: new_admin_menu_publication_path(@recording) }, status: :conflict
  end

  def invalid_publication(error)
    flash.now[:alert] = error.message
    render :new, status: :unprocessable_entity
  end
end
