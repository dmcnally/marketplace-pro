module ApplicationHelper
  include SysAdminHelper
  include AdminHelper

  def navigation_actions
    @navigation_actions ||= NavigationActions.new(view: self, person: Current.person, bucket: Current.bucket)
  end

  def form_with(model: false, scope: nil, url: nil, format: nil, **options, &block)
    if Rails.application.config.x.disable_html5_validations
      options[:html] = (options[:html] || {}).merge(novalidate: true)
    end

    super(model: model, scope: scope, url: url, format: format, **options, &block)
  end

  def approval_actions
    @approval_actions ||= ApprovalActions.new(view: self, person: Current.person, bucket: Current.bucket)
  end

  def article_actions
    @article_actions ||= ArticlesActions.new(view: self, person: Current.person, bucket: Current.bucket)
  end

  def publication_actions
    @publication_actions ||= PublicationsActions.new(view: self, person: Current.person, bucket: Current.bucket)
  end

  def comment_actions
    @comment_actions ||= CommentsActions.new(view: self, person: Current.person, bucket: Current.bucket)
  end

  def timeline_actions
    @timeline_actions ||= TimelineActions.new(view: self, person: Current.person, bucket: Current.bucket)
  end

  def diff_actions
    @diff_actions ||= DiffActions.new(view: self, person: Current.person, bucket: Current.bucket)
  end

  def invitation_actions
    @invitation_actions ||= InvitationActions.new(view: self, person: Current.person, bucket: Current.bucket)
  end

  def session_actions
    @session_actions ||= SessionActions.new(view: self, person: Current.person, bucket: Current.bucket)
  end
end
