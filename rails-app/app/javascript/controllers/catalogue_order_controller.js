import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item"]

  connect() {
    this.refresh()
  }

  up(event) {
    this.move(event.currentTarget, -1)
  }

  down(event) {
    this.move(event.currentTarget, 1)
  }

  move(button, offset) {
    const item = button.closest('[data-catalogue-order-target="item"]')
    const index = this.itemTargets.indexOf(item)
    const neighbor = this.itemTargets[index + offset]
    if (!neighbor) return

    if (offset < 0) neighbor.before(item)
    else neighbor.after(item)
    this.refresh()
    item.querySelector('[data-order-number]').focus()
  }

  refresh() {
    this.itemTargets.forEach((item, index) => {
      item.querySelector('[data-order-input]').value = index + 1
      item.querySelector('[data-order-number]').textContent = index + 1
      item.querySelector('[data-order-up]').disabled = index === 0
      item.querySelector('[data-order-down]').disabled = index === this.itemTargets.length - 1
    })
  }
}
