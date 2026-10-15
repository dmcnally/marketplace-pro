import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  focus(event) {
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
      event.preventDefault()
      this.inputTarget.focus()
    }
  }
}
