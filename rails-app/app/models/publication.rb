class Publication < ApplicationRecord
  belongs_to :publishable, polymorphic: true
end
