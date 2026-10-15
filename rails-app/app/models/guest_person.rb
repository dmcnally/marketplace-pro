class GuestPerson
  def id
  end

  def person_card
  end

  def guest?
    true
  end

  def buckets
    []
  end

  def membership_for(_bucket)
  end

  def member_of?(_bucket)
    false
  end

  def admin_of?(_bucket)
    false
  end

  def editor_of?(_bucket)
    false
  end

  def viewer_of?(_bucket)
    false
  end

  def sys_admin?
    false
  end
end
