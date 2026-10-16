require "test_helper"
require_relative "../../test_helpers/catalogue_test_helper"

class Catalogue::SnapshotTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  test "requires content and a recording and forbids changing or destroying a saved snapshot" do
    refute Catalogue::Snapshot.new.valid?
    product = create_catalogue_product
    snapshot = Catalogue::Snapshot.create!(recording: product, content: { "name" => "Wings" })
    assert_raises(ActiveRecord::ReadOnlyRecord) { snapshot.update!(content: { "name" => "Changed" }) }
    assert_raises(ActiveRecord::ReadOnlyRecord) { snapshot.reload.destroy! }
    assert_equal "Wings", snapshot.reload.content.fetch("name")
  end
end
