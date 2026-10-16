require "test_helper"

class AllergenPolicyTest < ActiveSupport::TestCase
  test "only editors and admins can manage allergens in their own bucket" do
    allergen = Current.bucket.recordings.create!(recordable: Allergen.new(name: "Food"))
    policy = AllergenPolicy.new(person: Current.person, bucket: Current.bucket)
    refute policy.can_create?
    membership = Membership.create!(person: Current.person, bucket: Current.bucket, role: :viewer)
    refute policy.can_view?(allergen)
    %i[editor admin].each do |role|
      membership.update!(role: role)
      assert policy.can_create?
      assert policy.can_edit?(allergen)
      assert policy.can_archive?(allergen)
      refute policy.can_restore?(allergen)
    end
    other = Bucket.create!(name: "Another bucket").recordings.create!(recordable: Allergen.new(name: "Other"))
    refute policy.can_edit?(other)
    allergen.archive_content!(revision: allergen.draft_revision)
    refute policy.can_edit?(allergen)
    assert policy.can_restore?(allergen)
    refute AllergenPolicy.new(person: GuestPerson.new, bucket: Current.bucket).can_view?(allergen)
    article = Current.bucket.recordings.create!(recordable: Article.new(title: "Wrong"))
    assert_raises(ArgumentError) { policy.can_edit?(article) }
  end
end
