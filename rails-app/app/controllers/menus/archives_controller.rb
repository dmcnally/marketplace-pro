class Menus::ArchivesController < ApplicationController
  include CatalogueFeedback
  layout "catalogue"
  before_action :authorize_management
  rescue_from Recording::CatalogueEditing::StaleDraft, with: :stale_draft

  def index
    @archives = recordings.menus.discarded.includes(:recordable)
  end

  def new
    @recording = archived_subject
    raise Authorization::Denied unless policy.can_archive?(@recording)
  end

  def create
    recording = archived_subject
    raise Authorization::Denied unless policy.can_archive?(recording)

    recording.archive_content!(revision: params[:revision])
    redirect_to admin_archived_menus_path, notice: "Menu archived. It is no longer live. Published versions and history are preserved.", status: :see_other
  end

  def destroy
    recording = archived_subject
    raise Authorization::Denied unless policy.can_restore?(recording)

    recording.restore_content!(revision: params[:revision])
    redirect_to edit_admin_menu_path(recording), notice: "Menu restored as an unpublished draft. The live menu is unchanged.", status: :see_other
  end

  private

  def archived_subject = recordings.menus.find(params[:menu_id])
  def policy = MenuPolicy.new(person: Current.person, bucket: Current.bucket)

  def authorize_management
    raise Authorization::Denied unless policy.can_create?
  end

  def stale_draft
    render "catalogue/stale", locals: { reload_path: admin_menus_path }, status: :conflict
  end
end
