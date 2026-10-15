class Recordings::DiffsController < ApplicationController
  allow_unauthenticated_access only: [ :show ]

  before_action :set_recording

  def show
    return head :forbidden unless @recording.viewable_by?(Current.person)

    @diff = @recording.previous_diff
  end

  private

  def set_recording
    @recording = recordings.find(params[:recording_id])
  end
end
