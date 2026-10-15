module Diffable
  extend ActiveSupport::Concern

  def diffable?
    false
  end

  class_methods do
    def recordable_fields
      attribute_names - %w[id created_at updated_at]
    end
  end
end
