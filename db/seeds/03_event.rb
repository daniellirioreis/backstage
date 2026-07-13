puts "→ Criando evento..."

event = Event.find_or_create_by!(name: "Boombay 2026") do |e|
  e.location   = "Belo Horizonte, MG"
  e.start_date = Date.new(2026, 4, 18)
  e.end_date   = Date.new(2026, 4, 26)
  e.status     = "active"
  e.code       = "BBY26"
  e.event_type = "festival"
end
event.update_columns(event_type: "festival") if event.event_type.blank?

# ── Funções do Boombay 2026 (copiadas do catálogo) ────────────────────────────
catalog_names = [
  "Técnico de Som", "Técnico de Iluminação", "Roadie",
  "Segurança", "Coord. de Segurança",
  "Atendente de Bar", "Bartender", "Garçom",
  "Agente de Limpeza", "Assistente de Limpeza",
  "Recepcionista", "Caixa de Bilheteria",
  "Assistente de Produção", "Coordenador de Produção",
  "Montador", "Motorista",
]

catalog_names.each do |name|
  catalog_fn = EventFunction.find_by(event_id: nil, name: name)
  next unless catalog_fn
  EventFunction.find_or_create_by!(event: event, name: name) do |ef|
    ef.hourly_rate = catalog_fn.hourly_rate
  end
end

puts "   Eventos: #{Event.count}"
puts "   Funções Boombay: #{event.event_functions.count}"
