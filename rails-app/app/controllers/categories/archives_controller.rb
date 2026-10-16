class Categories::ArchivesController < ApplicationController
  include CatalogueFeedback
  layout "catalogue"
  rescue_from Recording::CatalogueEditing::StaleDraft, with: :stale_draft

  def create
    recording = recordings.categories.find(params[:category_id])
    raise Authorization::Denied unless category_policy.can_archive?(recording)

    recording.archive_content!(revision: params[:revision])
    redirect_to admin_categories_path, notice: "Category archived. Existing assignments and history are preserved.", status: :see_other
  end

  def destroy
    recording = recordings.categories.find(params[:category_id])
    raise Authorization::Denied unless category_policy.can_restore?(recording)

    recording.restore_content!(revision: params[:revision])
    redirect_to admin_categories_path, notice: "Category restored and available for assignment.", status: :see_other
  end

  private

  def category_policy
    CategoryPolicy.new(person: Current.person, bucket: Current.bucket)
  end

  def stale_draft
    render "catalogue/stale", status: :conflict
  end
end
