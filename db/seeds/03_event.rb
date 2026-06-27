puts "→ Criando evento..."

Event.find_or_create_by!(name: "Boombay 2026") do |e|
  e.location   = "Belo Horizonte, MG"
  e.start_date = Date.new(2026, 4, 18)
  e.end_date   = Date.new(2026, 4, 26)
  e.status     = "active"
end

puts "   Eventos: #{Event.count}"
