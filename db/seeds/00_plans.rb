puts "→ Criando planos padrão..."

plans = [
  {
    name:          "Gratuito",
    events_limit:  3,
    members_limit: 30,
    description:   "Ideal para começar. Até 3 eventos simultâneos e 30 colaboradores."
  },
  {
    name:          "Pro",
    events_limit:  nil,
    members_limit: 500,
    description:   "Eventos ilimitados, até 500 colaboradores, dashboard financeiro completo e suporte prioritário."
  },
  {
    name:          "Enterprise",
    events_limit:  nil,
    members_limit: nil,
    description:   "Colaboradores e eventos ilimitados. Integrações customizadas, SLA garantido e CSM dedicado."
  }
]

plans.each do |attrs|
  plan = Plan.find_or_initialize_by(name: attrs[:name])
  plan.assign_attributes(attrs)
  plan.save!
  puts "   #{plan.name} — eventos: #{plan.events_limit_label} | colaboradores: #{plan.members_limit_label}"
end

puts "   Total: #{Plan.count} planos"
