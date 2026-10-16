module CatalogueFeedback
  extend ActiveSupport::Concern

  private

  def authorization_denied
    render "catalogue/forbidden", layout: "application", status: :forbidden
  end
end
