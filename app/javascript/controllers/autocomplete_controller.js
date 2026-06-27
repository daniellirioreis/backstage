import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "dropdown", "tags", "empty"]
  static values  = { url: String, existing: Array, param: String }

  connect() {
    this.selected = []
    this.coordinatorId = null
    this.debounceTimer = null

    // Carrega usuários já vinculados
    this.existingValue.forEach(u => this.#addUser(u))

    document.addEventListener("click", this.#closeOnOutside)
    document.addEventListener("coordinator-changed", this.#onCoordinatorChanged)
  }

  disconnect() {
    document.removeEventListener("click", this.#closeOnOutside)
    document.removeEventListener("coordinator-changed", this.#onCoordinatorChanged)
  }

  // ── Busca ─────────────────────────────────────────────────────────────────

  focus() {
    this.#fetch(this.inputTarget.value.trim())
  }

  search() {
    clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => {
      this.#fetch(this.inputTarget.value.trim())
    }, 220)
  }

  async #fetch(q) {
    const res    = await fetch(`${this.urlValue}?q=${encodeURIComponent(q)}`)
    const users  = await res.json()
    const filtered = users.filter(u =>
      !this.selected.find(s => s.id == u.id) &&
      String(u.id) !== String(this.coordinatorId)
    )
    this.#renderDropdown(filtered)
  }

  #onCoordinatorChanged = (e) => {
    this.coordinatorId = e.detail.coordinatorId
  }

  pick(event) {
    const item = event.currentTarget
    this.#addUser({ id: item.dataset.id, name: item.dataset.name, cpf: item.dataset.cpf })
    this.inputTarget.value = ""
    this.#hideDropdown()
    this.inputTarget.focus()
  }

  remove(event) {
    const id = event.currentTarget.dataset.id
    this.selected = this.selected.filter(u => u.id != id)
    event.currentTarget.closest(".autocomplete-tag").remove()
    this.element.querySelector(`input[value="${id}"]`)?.remove()
    this.#updateEmpty()
  }

  // ── Privados ──────────────────────────────────────────────────────────────

  #addUser(user) {
    if (this.selected.find(u => u.id == user.id)) return
    this.selected.push(user)

    // Tag visual
    const tag = document.createElement("div")
    tag.className = "autocomplete-tag"
    tag.innerHTML = `
      <span class="autocomplete-tag-name">${user.name}</span>
      <span class="autocomplete-tag-cpf">${user.cpf}</span>
      <button type="button" class="autocomplete-tag-remove"
              data-id="${user.id}"
              data-action="click->autocomplete#remove">×</button>
    `
    this.tagsTarget.appendChild(tag)

    // Hidden input para o form
    const hidden = document.createElement("input")
    hidden.type  = "hidden"
    hidden.name  = this.paramValue
    hidden.value = user.id
    this.element.appendChild(hidden)

    this.#updateEmpty()
  }

  #renderDropdown(users) {
    if (!users.length) { this.#hideDropdown(); return }

    this.dropdownTarget.innerHTML = users.map(u => `
      <div class="autocomplete-item"
           data-id="${u.id}" data-name="${u.name}" data-cpf="${u.cpf}"
           data-action="click->autocomplete#pick">
        <span class="autocomplete-item-name">${u.name}</span>
        <span class="autocomplete-item-cpf">${u.cpf}</span>
      </div>
    `).join("")

    this.dropdownTarget.style.display = "block"
  }

  #hideDropdown() {
    this.dropdownTarget.style.display = "none"
    this.dropdownTarget.innerHTML = ""
  }

  #updateEmpty() {
    if (this.hasEmptyTarget) {
      this.emptyTarget.style.display = this.selected.length ? "none" : "block"
    }
  }

  #closeOnOutside = (e) => {
    if (!this.element.contains(e.target)) this.#hideDropdown()
  }
}
