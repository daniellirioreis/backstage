import { Controller } from "@hotwired/stimulus"
import TomSelect from "tom-select"

export default class extends Controller {
  connect() {
    this.ts = new TomSelect(this.element, {
      placeholder:  "Buscar equipe...",
      searchField:  ["text"],   // busca no texto do option
      sortField:    "text",
      render: {
        option: (data) => {
          const parts = data.text.split(" › ")
          const sector = parts[0] || ""
          const name   = parts[1] || data.text
          return `
            <div style="padding: 0.15rem 0;">
              <div style="font-size: 0.7rem; color: #a1a1aa; text-transform: uppercase; letter-spacing: 0.04em;">${sector}</div>
              <div style="font-weight: 500; color: #18181b;">${name}</div>
            </div>
          `
        },
        item: (data) => {
          const parts  = data.text.split(" › ")
          const sector = parts[0] || ""
          const name   = parts[1] || data.text
          return `
            <div style="display: flex; align-items: center; gap: 0.3rem;">
              <span style="font-size: 0.72rem; color: #a1a1aa;">${sector} ›</span>
              <span style="font-weight: 500; color: #18181b;">${name}</span>
            </div>
          `
        },
        no_results: () => `<div style="padding: 0.5rem 0.75rem; color: #a1a1aa; font-size: 0.85rem;">Nenhuma equipe encontrada</div>`,
      },
      onChange: () => {
        this.element.form.submit()
      }
    })
  }

  disconnect() {
    this.ts?.destroy()
  }
}
