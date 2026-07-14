puts "→ Criando setores..."

event = Event.find_by!(name: "Boombay 2026")

[
  "Carregadores",
  "Limpeza",
  "Guarda Volumes",
  "Guarda Volume Staff",
  "Lojinha",
  "Controle de Consumo",
  "Mega Fone",
  "Backstage",
  "Estoque Lojinha",
  "Caixa Ticket Social",
  "Troca de Alimento",
  "Bilheteria",
].each do |name|
  Sector.find_or_create_by!(name: name, event: event)
end

puts "   Setores: #{Sector.count}"
