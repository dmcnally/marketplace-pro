module CatalogueTestHelper
  def create_catalogue_menu(**attributes)
    draft = Menu::Draft.new(bucket: Current.bucket, name: "Evening menu", **attributes)
    assert draft.save, draft.errors.full_messages.join(", ")
    draft.recording.reload
  end

  def add_menu_section(menu, **attributes)
    draft = MenuSection::Draft.new(menu: menu, revision: menu.reload.draft_revision, name: "Starters", **attributes)
    assert draft.save, draft.errors.full_messages.join(", ")
    draft.recording.reload
  end

  def with_class_method_replacement(klass, method_name, replacement)
    owned = klass.singleton_class.instance_methods(false).include?(method_name)
    original = klass.method(method_name)
    klass.define_singleton_method(method_name, replacement)
    yield
  ensure
    if owned
      klass.define_singleton_method(method_name, original)
    else
      klass.singleton_class.remove_method(method_name)
    end
  end

  def create_catalogue_product(**attributes)
    draft = Product::Draft.new(bucket: Current.bucket, name: "Wings", price: "5.95", **attributes)
    assert draft.save, draft.errors.full_messages.join(", ")
    draft.recording.reload
  end

  def add_catalogue_variant(product, **attributes)
    draft = Product::VariantDraft.new(product: product, revision: product.reload.draft_revision,
      source_id: product.recordable.variant_order.first, name: "Large", price: "8.50", **attributes)
    assert draft.save, draft.errors.full_messages.join(", ")
    draft.recording.reload
  end

  def assert_immutable_content(content)
    assert_raises(ActiveRecord::ReadOnlyRecord) { content.update!(name: "Changed") }
    assert_raises(ActiveRecord::ReadOnlyRecord) { content.reload.destroy! }
  end
end
