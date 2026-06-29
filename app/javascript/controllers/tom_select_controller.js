import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.tomSelect = new window.TomSelect(this.element, {
      placeholder: this.element.dataset.placeholder || "— Selecione —",
      allowEmptyOption: true,
      maxOptions: null,
    })
  }

  disconnect() {
    if (this.tomSelect) {
      this.tomSelect.destroy()
    }
  }
}
