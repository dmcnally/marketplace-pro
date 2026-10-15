class SysAdmin::Actions
  def initialize(view:, person:, bucket: nil)
    @view = view
    @person = person
    @bucket = bucket
  end

  def banner_exit_bucket_button
    return unless person.sys_admin? && bucket.present?

    view.button_to "Exit Bucket",
                   view.bucket_switch_path(bucket),
                   method: :delete,
                   class: "sys-admin-banner__link sys-admin-banner__button",
                   form_class: "sys-admin-banner__form"
  end

  private

  attr_reader :view, :person, :bucket
end
