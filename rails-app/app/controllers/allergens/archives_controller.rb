class Allergens::ArchivesController < ApplicationController
  include CatalogueFeedback
  layout "catalogue"
  rescue_from Recording::CatalogueEditing::StaleDraft, with: :stale_draft

  def create
    recording = recordings.allergens.find(params[:allergen_id])
    raise Authorization::Denied unless allergen_policy.can_archive?(recording)

    recording.archive_content!(revision: params[:revision])
    redirect_to admin_allergens_path, notice: "Allergen archived. Existing assignments and history are preserved.", status: :see_other
  end

  def destroy
    recording = recordings.allergens.find(params[:allergen_id])
    raise Authorization::Denied unless allergen_policy.can_restore?(recording)

    recording.restore_content!(revision: params[:revision])
    redirect_to admin_allergens_path, notice: "Allergen restored and available for assignment.", status: :see_other
  end

  private

  def allergen_policy
    AllergenPolicy.new(person: Current.person, bucket: Current.bucket)
  end

  def stale_draft
    render "catalogue/stale", locals: { reload_path: admin_allergens_path }, status: :conflict
  end
end
