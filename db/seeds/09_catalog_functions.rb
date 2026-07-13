# Catálogo global de funções (event_id nil)
# Idempotente: find_or_create_by! não sobrescreve funções existentes.
#
# Uso isolado: docker compose exec web rails runner db/seeds/09_catalog_functions.rb

puts "\n→ Catálogo de funções"

catalog = [
  # Palco / Estrutura / Técnica
  { name: "Técnico de Som",          hourly_rate: 39.0 },
  { name: "Técnico de Iluminação",   hourly_rate: 39.0 },
  { name: "Técnico de AV",           hourly_rate: 35.0 },
  { name: "Iluminador",              hourly_rate: 35.0 },
  { name: "Operador de Câmera",      hourly_rate: 30.0 },
  { name: "Roadie",                  hourly_rate: 20.0 },
  { name: "Assistente de Palco",     hourly_rate: 15.0 },

  # Produção / Coordenação
  { name: "Coordenador de Produção", hourly_rate: 40.0 },
  { name: "Assistente de Produção",  hourly_rate: 30.0 },
  { name: "Host",                    hourly_rate: 35.0 },

  # Logística / Infraestrutura
  { name: "Montador",                hourly_rate: 22.0 },
  { name: "Motorista",               hourly_rate: 20.0 },

  # Segurança
  { name: "Segurança",               hourly_rate: 20.0 },
  { name: "Coord. de Segurança",     hourly_rate: 28.0 },

  # Portaria / Credenciamento
  { name: "Recepcionista",           hourly_rate: 15.0 },
  { name: "Caixa de Bilheteria",     hourly_rate: 10.0 },

  # Alimentação / Bar
  { name: "Bartender",               hourly_rate: 18.0 },
  { name: "Garçom",                  hourly_rate: 15.0 },
  { name: "Atendente de Bar",        hourly_rate: 12.0 },
  { name: "Cozinheiro",              hourly_rate: 25.0 },
  { name: "Cozinheira",              hourly_rate: 25.0 },
  { name: "Assistente de Cozinha",   hourly_rate: 12.0 },

  # Limpeza
  { name: "Agente de Limpeza",       hourly_rate: 12.0 },
  { name: "Assistente de Limpeza",   hourly_rate: 10.0 },

  # Saúde
  { name: "Socorrista",              hourly_rate: 35.0 },
  { name: "Auxiliar de Enfermagem",  hourly_rate: 28.0 },
]

created = 0
catalog.each do |attrs|
  ef = EventFunction.find_or_initialize_by(name: attrs[:name], event_id: nil)
  if ef.new_record?
    ef.hourly_rate = attrs[:hourly_rate]
    ef.save!
    created += 1
  end
end

puts "   #{created} novas funções adicionadas ao catálogo (#{EventFunction.catalog.count} total)"
