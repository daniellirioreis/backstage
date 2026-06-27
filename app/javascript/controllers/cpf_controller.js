import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field"]

  connect() {
    this.applyMask()
  }

  mask(event) {
    this.applyMask()
  }

  applyMask() {
    const field = this.fieldTarget
    let digits = field.value.replace(/\D/g, "").slice(0, 11)

    let masked = digits
    if (digits.length > 9) {
      masked = `${digits.slice(0,3)}.${digits.slice(3,6)}.${digits.slice(6,9)}-${digits.slice(9)}`
    } else if (digits.length > 6) {
      masked = `${digits.slice(0,3)}.${digits.slice(3,6)}.${digits.slice(6)}`
    } else if (digits.length > 3) {
      masked = `${digits.slice(0,3)}.${digits.slice(3)}`
    }

    field.value = masked
  }
}
