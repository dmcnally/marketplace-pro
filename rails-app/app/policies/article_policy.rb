class ArticlePolicy < RecordablePolicy
  def can_create?
    bucket_admin?
  end

  def can_edit?(recording)
    assert_recordable!(recording)

    bucket_admin?
  end

  def can_delete?(recording)
    assert_recordable!(recording)

    bucket_admin?
  end

  def can_publish?(recording)
    assert_recordable!(recording)

    recording.bucket == bucket && recording.publishable? && bucket_admin?
  end

  def can_comment_on?(recording)
    assert_recordable!(recording)

    recording.commentable? && person.viewer_of?(bucket)
  end
end
