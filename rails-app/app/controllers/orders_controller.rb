class OrdersController < ApplicationController
  layout "staff"

  def index
    raise Authorization::Denied unless OrderPolicy.new(person: Current.person, bucket: Current.bucket).can_view?
  end
end
