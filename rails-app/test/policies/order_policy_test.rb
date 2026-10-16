require "test_helper"

class OrderPolicyTest < ActiveSupport::TestCase
  test "every accepted member can view orders while guests and outsiders cannot" do
    bucket = Current.bucket
    person = users(:two).person
    policy = OrderPolicy.new(person: person, bucket: bucket)
    refute policy.can_view?
    membership = Membership.create!(person: person, bucket: bucket, role: :viewer)
    %i[viewer editor admin].each do |role|
      membership.update!(role: role)
      assert policy.can_view?
    end
    refute OrderPolicy.new(person: GuestPerson.new, bucket: bucket).can_view?
    refute OrderPolicy.new(person: person, bucket: nil).can_view?
    refute OrderPolicy.new(person: person, bucket: Bucket.create!(name: "Other")).can_view?
  end
end
