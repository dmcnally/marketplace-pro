require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "form_with disables native browser validations when configured" do
    with_html5_validations_disabled(true) do
      html = form_with(url: "/test") { "Body" }

      assert_includes html, "novalidate"
    end
  end

  test "form_with keeps default validation behavior when not configured" do
    with_html5_validations_disabled(false) do
      html = form_with(url: "/test") { "Body" }

      refute_includes html, "novalidate"
    end
  end

  private

  def with_html5_validations_disabled(value)
    original = Rails.application.config.x.disable_html5_validations

    Rails.application.config.x.disable_html5_validations = value
    yield
  ensure
    Rails.application.config.x.disable_html5_validations = original
  end
end
