import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "dropdown", "selected", "hidden"]
  static values  = { url: String, existing: Object }

  connect() {
    this.debounceTimer = null

    if (this.existingValue?.id) this.#render(this.existingValue)

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
      const teams = await res.json()
      this.#renderDropdown(teams)
    }, 220)
  }

  pick(event) {
    const item = event.currentTarget
    const team = {
      id:     item.dataset.id,
      name:   item.dataset.name,
      sector: item.dataset.sector
    }
    this.#render(team)
    this.inputTarget.value = ""
    this.#hideDropdown()

    // Submete o form para carregar os colaboradores da equipe
    this.element.closest("form").submit()
  }

  clear() {
    this.selectedTarget.innerHTML = ""
    this.hiddenTarget.value = ""
    this.inputTarget.style.display = "block"
    this.inputTarget.focus()
  }

  // ── Privados ────────────────────────────────────────────────────────────────

  #render(team) {
    this.hiddenTarget.value = team.id
    this.inputTarget.style.display = "none"

    this.selectedTarget.innerHTML = `
      <div class="autocomplete-tag" style="display: inline-flex; align-items: center; gap: 0.4rem;">
        <span style="font-size: 0.72rem; color: #a1a1aa;">${team.sector} ›</span>
        <span class="autocomplete-tag-name">${team.name}</span>
        <button type="button" class="autocomplete-tag-remove"
                data-action="click->team-autocomplete#clear">×</button>
      </div>
    `
  }

  #renderDropdown(teams) {
    if (!teams.length) { this.#hideDropdown(); return }

    this.dropdownTarget.innerHTML = teams.map(t => `
      <div class="autocomplete-item"
           data-id="${t.id}" data-name="${t.name}" data-sector="${t.sector}"
           data-action="click->team-autocomplete#pick">
        <div style="min-width: 0; flex: 1;">
          <div style="font-size: 0.7rem; color: #a1a1aa; text-transform: uppercase; letter-spacing: 0.04em;">${t.sector}</div>
          <div class="autocomplete-item-name">${t.name}</div>
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
