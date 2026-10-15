class SysAdmin::BucketActions
  def initialize(view:, person:)
    @view = view
    @person = person
  end

  def new_link
    return unless sys_admin?

    view.link_to "New Bucket", view.new_sys_admin_bucket_path, class: "btn btn--primary"
  end

  def index_link
    return unless sys_admin?

    view.link_to "Buckets", view.sys_admin_buckets_path, class: "btn btn--primary"
  end

  def edit_link_for(bucket)
    return unless sys_admin?

    view.link_to "Edit", view.edit_sys_admin_bucket_path(bucket), class: "btn btn--secondary"
  end

  def show_link_for(bucket)
    return unless sys_admin?

    view.link_to "View", view.sys_admin_bucket_path(bucket), class: "btn btn--secondary"
  end

  def switch_button_for(bucket)
    return unless sys_admin?
    return unless bucket.content?

    view.button_to "Switch",
                   view.bucket_switch_path(bucket),
                   method: :post,
                   class: "btn btn--secondary",
                   form_class: "bucket-list__action-form"
  end

  private

  attr_reader :view, :person

  def sys_admin?
    person.sys_admin?
  end
end
