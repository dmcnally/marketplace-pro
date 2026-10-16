import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["disclosure"]

  connect() {
    this.breakpoint = window.matchMedia("(max-width: 700px)")
    this.updateLayout = () => { this.disclosureTarget.open = !this.breakpoint.matches }
    this.breakpoint.addEventListener("change", this.updateLayout)
    this.updateLayout()
  }

  disconnect() {
    this.breakpoint.removeEventListener("change", this.updateLayout)
  }
}
