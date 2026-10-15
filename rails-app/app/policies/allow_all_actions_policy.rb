# Explicitly injected permission checker for presenter tests and permissive demos.
# Policy lookup never falls back to this class.
class AllowAllActionsPolicy
  def allowed?(_action, _subject)
    true
  end
end
