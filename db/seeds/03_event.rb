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

puts "   Eventos: #{Event.count}"
