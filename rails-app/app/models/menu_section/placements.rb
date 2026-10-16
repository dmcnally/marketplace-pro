class MenuSection::Placements
  def initialize(menu, section)
    raise ArgumentError, "Expected a menu section" unless menu.menu? && section.menu_section?

    @menu = menu
    @section = section
  end

  def reorder!(ids, revision:)
    Menu::Structure.new(@menu).change!(revision) do
      raise ActiveRecord::RecordNotFound unless @section.parent_id == @menu.id && @menu.recordable.section_order.include?(@section.id)

      @section.reload
      order = ids.map(&:to_i)
      raise ArgumentError, "Include every product exactly once." unless order.sort == @section.recordable.product_ids.sort

      previous = @section.recordable
      content = MenuSection.new(previous.attributes.except("id").merge("product_ids" => order))
      content.image.attach(previous.image.blob) if previous.image.attached?
      @section.update!(recordable: content)
    end
  end
end
