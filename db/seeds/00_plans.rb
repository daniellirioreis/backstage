puts "→ Criando/atualizando planos..."

plans = [
  {
    name:          "Gratuito",
    price:         0,
    events_limit:  1,
    members_limit: 20,
    description:   "Para experimentar o sistema"
  },
  {
    name:          "Básico",
    price:         89.00,
    events_limit:  5,
    members_limit: 100,
    description:   "Para pequenas produtoras"
  },
  {
    name:          "Pro",
    price:         199.00,
    events_limit:  20,
    members_limit: 500,
    description:   "Para produtoras com eventos frequentes"
  },
  {
    name:          "Enterprise",
    price:         499.00,
    events_limit:  nil,
    members_limit: nil,
    description:   "Eventos e colaboradores ilimitados"
  }
]

plans.each do |attrs|
  plan = Plan.find_or_initialize_by(name: attrs[:name])
  plan.assign_attributes(attrs)
  plan.save!
  price_label = plan.price.to_f > 0 ? "R$ #{"%.2f" % plan.price}/mês" : "Gratuito"
  puts "   #{plan.name} — #{price_label} | eventos: #{plan.events_limit_label} | colaboradores: #{plan.members_limit_label}"
end

puts "   Total: #{Plan.count} planos"
