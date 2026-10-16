class Menus::PreviewsController < ApplicationController
  include CatalogueFeedback
  layout "catalogue"

  def show
    menu = recordings.menus.find(params[:menu_id])
    raise Authorization::Denied unless MenuPolicy.new(person: Current.person, bucket: Current.bucket).can_view?(menu)

    @preview = Menu::Preview.new(menu)
  end
end
