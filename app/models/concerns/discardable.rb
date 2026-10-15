module Discardable
  extend ActiveSupport::Concern

  included do
    scope :kept, -> { where(discarded_at: nil) }
    scope :discarded, -> { where.not(discarded_at: nil) }

    define_callbacks :discard
  end

  class_methods do
    def before_discard(*args, &block)
      set_callback(:discard, :before, *args, &block)
    end

    def after_discard(*args, &block)
      set_callback(:discard, :after, *args, &block)
    end
  end

  def discard!
    return if discarded?

    run_callbacks(:discard) do
      update!(discarded_at: Time.current)
    end
  end

  def restore!
    return unless discarded?

    update!(discarded_at: nil)
  end

  def discarded?
    discarded_at.present?
  end

  def kept?
    !discarded?
  end
end
