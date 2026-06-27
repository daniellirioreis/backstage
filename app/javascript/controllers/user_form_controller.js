import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["name", "email", "cpf", "role", "nameError", "emailError", "cpfError", "roleError"]

  connect() {
    this.nameTarget.addEventListener("blur", () => this.validateName())
    this.emailTarget.addEventListener("blur", () => this.validateEmail())
    this.cpfTarget.addEventListener("blur", () => this.validateCpf())
    this.roleTarget.addEventListener("change", () => this.validateRole())
  }

  submit(event) {
    const valid = [
      this.validateName(),
      this.validateEmail(),
      this.validateCpf(),
      this.validateRole(),
    ].every(Boolean)

    if (!valid) {
      event.preventDefault()
      this.element.querySelector(".field-invalid")?.focus()
    }
  }

  // ── Validações individuais ──────────────────────────────────────────────────

  validateName() {
    const val = this.nameTarget.value.trim()
    if (!val) return this.#setError(this.nameTarget, this.nameErrorTarget, "Nome é obrigatório")
    if (val.length < 3) return this.#setError(this.nameTarget, this.nameErrorTarget, "Mínimo 3 caracteres")
    return this.#clearError(this.nameTarget, this.nameErrorTarget)
  }

  validateEmail() {
    const val = this.emailTarget.value.trim()
    const re  = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    if (!val) return this.#setError(this.emailTarget, this.emailErrorTarget, "E-mail é obrigatório")
    if (!re.test(val)) return this.#setError(this.emailTarget, this.emailErrorTarget, "E-mail inválido")
    return this.#clearError(this.emailTarget, this.emailErrorTarget)
  }

  validateCpf() {
    const digits = this.cpfTarget.value.replace(/\D/g, "")
    if (!digits) return this.#setError(this.cpfTarget, this.cpfErrorTarget, "CPF é obrigatório")
    if (digits.length !== 11) return this.#setError(this.cpfTarget, this.cpfErrorTarget, "CPF incompleto")
    if (!this.#cpfValid(digits)) return this.#setError(this.cpfTarget, this.cpfErrorTarget, "CPF inválido")
    return this.#clearError(this.cpfTarget, this.cpfErrorTarget)
  }

  validateRole() {
    const val = this.roleTarget.value
    if (!val) return this.#setError(this.roleTarget, this.roleErrorTarget, "Perfil é obrigatório")
    return this.#clearError(this.roleTarget, this.roleErrorTarget)
  }

  // ── Helpers privados ───────────────────────────────────────────────────────

  #setError(field, errorEl, message) {
    field.style.borderColor = "#ef4444"
    field.classList.add("field-invalid")
    errorEl.textContent = message
    errorEl.style.display = "block"
    return false
  }

  #clearError(field, errorEl) {
    field.style.borderColor = ""
    field.classList.remove("field-invalid")
    errorEl.textContent = ""
    errorEl.style.display = "none"
    return true
  }

  #cpfValid(digits) {
    if (new Set(digits).size === 1) return false

    const calc = (d, len) => {
      let sum = 0
      for (let i = 0; i < len; i++) sum += parseInt(d[i]) * (len + 1 - i)
      const rem = sum % 11
      return rem < 2 ? 0 : 11 - rem
    }

    return calc(digits, 9) === parseInt(digits[9]) &&
           calc(digits, 10) === parseInt(digits[10])
  }
}
