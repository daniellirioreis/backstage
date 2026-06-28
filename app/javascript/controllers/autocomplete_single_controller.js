import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "dropdown", "selected", "hidden"]
  static values  = { url: String, existing: Object, param: String }

  connect() {
    this.current = this.existingValue?.id ? this.existingValue : null
    this.debounceTimer = null

    if (this.current) this.#render(this.current)

    document.addEventListener("click", this.#closeOnOutside)
  }

  disconnect() {
    document.removeEventListener("click", this.#closeOnOutside)
  }

  search() {
    clearTimeout(this.debounceTimer)
    const q = this.inputTarget.value.trim()
    if (!q.length) { this.#hideDropdown(); return }

    this.debounceTimer = setTimeout(async () => {
      const res   = await fetch(`${this.urlValue}?q=${encodeURIComponent(q)}`)
      const users = await res.json()
      this.#renderDropdown(users)
    }, 220)
  }

  pick(event) {
    const item = event.currentTarget
    this.#render({
      id: item.dataset.id,
      name: item.dataset.name,
      cpf: item.dataset.cpf,
      avatar_url: item.dataset.avatarUrl || null,
      initials: item.dataset.initials || ""
    })
    this.inputTarget.value = ""
    this.#hideDropdown()
  }

  clear() {
    this.current = null
    this.selectedTarget.innerHTML = ""
    this.hiddenTarget.value = ""
    this.inputTarget.style.display = "block"
    this.inputTarget.focus()
    this.#dispatch(null)
  }

  // ── Privados ────────────────────────────────────────────────────────────────

  #avatarHtml(user, size = 24) {
    if (user.avatar_url) {
      return `<img src="${user.avatar_url}" style="width:${size}px;height:${size}px;border-radius:50%;object-fit:cover;flex-shrink:0;">`
    }
    return `<div style="width:${size}px;height:${size}px;border-radius:50%;background:#f4f4f5;border:1px solid #e4e4e7;display:flex;align-items:center;justify-content:center;font-size:${Math.round(size*0.38)}px;font-weight:600;color:#52525b;flex-shrink:0;">${user.initials || ""}</div>`
  }

  #render(user) {
    this.current = user
    this.hiddenTarget.value = user.id
    this.inputTarget.style.display = "none"

    this.selectedTarget.innerHTML = `
      <div class="autocomplete-tag" style="display: inline-flex; align-items: center; gap: 0.4rem;">
        ${this.#avatarHtml(user, 22)}
        <span class="autocomplete-tag-name">${user.name}</span>
        <span class="autocomplete-tag-cpf">${user.cpf}</span>
        <button type="button" class="autocomplete-tag-remove"
                data-action="click->autocomplete-single#clear">×</button>
      </div>
    `

    this.#dispatch(user.id)
  }

  #dispatch(id) {
    this.element.dispatchEvent(new CustomEvent("coordinator-changed", {
      bubbles: true,
      detail: { coordinatorId: id }
    }))
  }

  #renderDropdown(users) {
    if (!users.length) { this.#hideDropdown(); return }

    this.dropdownTarget.innerHTML = users.map(u => `
      <div class="autocomplete-item"
           data-id="${u.id}" data-name="${u.name}" data-cpf="${u.cpf}"
           data-avatar-url="${u.avatar_url || ""}" data-initials="${u.initials || ""}"
           data-action="click->autocomplete-single#pick">
        ${this.#avatarHtml(u, 28)}
        <div style="min-width:0;flex:1;">
          <div class="autocomplete-item-name">${u.name}</div>
          <div class="autocomplete-item-cpf">${u.cpf}</div>
        </div>
      </div>
    `).join("")

    this.dropdownTarget.style.display = "block"
  }

  #hideDropdown() {
    this.dropdownTarget.style.display = "none"
    this.dropdownTarget.innerHTML = ""
  }

  #closeOnOutside = (e) => {
    if (!this.element.contains(e.target)) this.#hideDropdown()
  }
}
