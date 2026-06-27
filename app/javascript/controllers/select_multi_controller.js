import { Controller } from "@hotwired/stimulus"
import TomSelect from "tom-select"

export default class extends Controller {
  static values = { url: String, existing: Array }

  connect() {
    this.ts = new TomSelect(this.element, {
      valueField: "id",
      labelField: "name",
      searchField: ["name", "cpf"],
      placeholder: "Buscar por nome ou CPF...",
      plugins: ["remove_button"],
      loadThrottle: 200,
      preload: false,
      items: this.existingValue.map(u => u.id),
      options: this.existingValue,
      load: (query, callback) => {
        if (!query.length) return callback()
        fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`)
          .then(r => r.json())
          .then(callback)
          .catch(() => callback())
      },
      render: {
        option: (data) => `
          <div style="display: flex; flex-direction: column; padding: 0.1rem 0;">
            <span style="font-weight: 500; color: #18181b;">${data.name}</span>
            <span style="font-size: 0.75rem; color: #a1a1aa; font-family: monospace;">${data.cpf || ""}</span>
          </div>
        `,
        item: (data) => `
          <div style="display: flex; gap: 0.35rem; align-items: center;">
            <span style="font-size: 0.82rem;">${data.name}</span>
            <span style="font-size: 0.72rem; color: #71717a; font-family: monospace;">${data.cpf || ""}</span>
          </div>
        `,
        no_results: () => `<div style="padding: 0.5rem 0.75rem; color: #a1a1aa; font-size: 0.85rem;">Nenhum resultado</div>`,
      },
    })
  }

  disconnect() {
    this.ts?.destroy()
  }
}
