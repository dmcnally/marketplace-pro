require "test_helper"

class CategoryPolicyTest < ActiveSupport::TestCase
  test "only editors and admins can manage categories in their own bucket" do
    category = Current.bucket.recordings.create!(recordable: Category.new(name: "Food"))
    policy = CategoryPolicy.new(person: Current.person, bucket: Current.bucket)
    refute policy.can_create?
    membership = Membership.create!(person: Current.person, bucket: Current.bucket, role: :viewer)
    refute policy.can_view?(category)
    %i[editor admin].each do |role|
      membership.update!(role: role)
      assert policy.can_create?
      assert policy.can_edit?(category)
      assert policy.can_archive?(category)
      refute policy.can_restore?(category)
    end
    other = Bucket.create!(name: "Another bucket").recordings.create!(recordable: Category.new(name: "Other"))
    refute policy.can_edit?(other)
    category.archive_content!(revision: category.draft_revision)
    refute policy.can_edit?(category)
    assert policy.can_restore?(category)
    refute CategoryPolicy.new(person: GuestPerson.new, bucket: Current.bucket).can_view?(category)
    article = Current.bucket.recordings.create!(recordable: Article.new(title: "Wrong"))
    assert_raises(ArgumentError) { policy.can_edit?(article) }
  end
end
