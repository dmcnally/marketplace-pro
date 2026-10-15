class PublicationsController < ApplicationController
  # POST /publication
  def create
    @publishable = GlobalID::Locator.locate_signed(params[:publishable], for: "publication")
    raise ActiveRecord::RecordNotFound unless @publishable
    raise ActiveRecord::RecordNotFound unless @publishable.respond_to?(:publish!)

    person_allowed_to!(:publish, @publishable)

    @publishable.publish!

    respond_to do |format|
      format.turbo_stream
      format.html { head :ok }
    end
  end

  # DELETE /publication
  def destroy
    @publishable = GlobalID::Locator.locate_signed(params[:publishable], for: "publication")
    raise ActiveRecord::RecordNotFound unless @publishable
    raise ActiveRecord::RecordNotFound unless @publishable.respond_to?(:unpublish!)

    person_allowed_to!(:publish, @publishable)

    @publishable.unpublish!

    respond_to do |format|
      format.turbo_stream
      format.html { head :ok }
    end
  end
end
