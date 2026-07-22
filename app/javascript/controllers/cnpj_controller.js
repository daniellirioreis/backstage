import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field", "error"]

  connect() {
    this.applyMask()
  }

  mask() {
    this.applyMask()
    if (this.hasErrorTarget) this.errorTarget.textContent = ""
  }

  applyMask() {
    const field = this.fieldTarget
    let digits = field.value.replace(/\D/g, "").slice(0, 14)

    let masked = digits
    if (digits.length > 12) {
      masked = `${digits.slice(0,2)}.${digits.slice(2,5)}.${digits.slice(5,8)}/${digits.slice(8,12)}-${digits.slice(12)}`
    } else if (digits.length > 8) {
      masked = `${digits.slice(0,2)}.${digits.slice(2,5)}.${digits.slice(5,8)}/${digits.slice(8)}`
    } else if (digits.length > 5) {
      masked = `${digits.slice(0,2)}.${digits.slice(2,5)}.${digits.slice(5)}`
    } else if (digits.length > 2) {
      masked = `${digits.slice(0,2)}.${digits.slice(2)}`
    }

    field.value = masked
  }

  validate() {
    if (!this.hasErrorTarget) return
    const digits = this.fieldTarget.value.replace(/\D/g, "")
    if (digits.length === 0) { this.errorTarget.textContent = ""; return }
    if (digits.length !== 14 || /^(\d)\1+$/.test(digits)) {
      this.errorTarget.textContent = "CNPJ inválido"
      return
    }

    const calc = (d, n) => {
      let sum = 0, w = n
      for (let i = 0; i < d.length; i++) { sum += parseInt(d[i]) * w--; if (w < 2) w = 9 }
      const r = sum % 11
      return r < 2 ? 0 : 11 - r
    }

    const d1 = calc(digits.slice(0, 12), 5)
    const d2 = calc(digits.slice(0, 13), 6)

    if (d1 !== parseInt(digits[12]) || d2 !== parseInt(digits[13])) {
      this.errorTarget.textContent = "CNPJ inválido"
    } else {
      this.errorTarget.textContent = ""
    }
  }
}
