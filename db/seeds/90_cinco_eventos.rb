# db/seeds/90_cinco_eventos.rb
#
# 5 eventos completos — cada um com setores, equipes (5–10 membros) e escalas diárias
#
# Uso: docker compose exec web rails runner db/seeds/90_cinco_eventos.rb

puts "\n→ Seed: 5 eventos completos"

company     = Company.first || Company.create!(name: "Produtora Horizonte")
admin       = User.joins(:role).where(roles: { name: "admin" }).first
collab_role = Role.find_by!(name: "colaborador")
abort "Admin não encontrado. Rode db:seed primeiro." unless admin

# ── Pool de 50 colaboradores ───────────────────────────────────────────────────

colabs_data = [
  ["Alice Mendes",      "600.001.001-01"], ["Bruno Costa",       "600.002.002-02"],
  ["Carla Figueiredo",  "600.003.003-03"], ["Diego Almeida",     "600.004.004-04"],
  ["Elena Ramos",       "600.005.005-05"], ["Fábio Lopes",       "600.006.006-06"],
  ["Gisele Nogueira",   "600.007.007-07"], ["Henrique Duarte",   "600.008.008-08"],
  ["Inês Cavalcanti",   "600.009.009-09"], ["João Pereira",      "600.010.010-10"],
  ["Kátia Ribeiro",     "600.011.011-11"], ["Leonardo Dias",     "600.012.012-12"],
  ["Mônica Santana",    "600.013.013-13"], ["Nilton Araujo",     "600.014.014-14"],
  ["Olga Teixeira",     "600.015.015-15"], ["Pedro Machado",     "600.016.016-16"],
  ["Quirino Martins",   "600.017.017-17"], ["Regina Borges",     "600.018.018-18"],
  ["Sérgio Vieira",     "600.019.019-19"], ["Tatiana Sousa",     "600.020.020-20"],
  ["Ubiratan Campos",   "600.021.021-21"], ["Vanessa Lima",      "600.022.022-22"],
  ["Wagner Freitas",    "600.023.023-23"], ["Ximena Torres",     "600.024.024-24"],
  ["Yago Barbosa",      "600.025.025-25"], ["Zara Cunha",        "600.026.026-26"],
  ["André Medeiros",    "600.027.027-27"], ["Beatriz Fontes",    "600.028.028-28"],
  ["César Oliveira",    "600.029.029-29"], ["Diana Pinto",       "600.030.030-30"],
  ["Eduardo Matos",     "600.031.031-31"], ["Fernanda Cruz",     "600.032.032-32"],
  ["Guilherme Silva",   "600.033.033-33"], ["Helena Rocha",      "600.034.034-34"],
  ["Igor Braga",        "600.035.035-35"], ["Juliana Neto",      "600.036.036-36"],
  ["Kauan Assis",       "600.037.037-37"], ["Larissa Queiroz",   "600.038.038-38"],
  ["Marcelo Farias",    "600.039.039-39"], ["Natalia Gomes",     "600.040.040-40"],
  ["Osmar Cardoso",     "600.041.041-41"], ["Patrícia Luz",      "600.042.042-42"],
  ["Rafael Sena",       "600.043.043-43"], ["Sabrina Melo",      "600.044.044-44"],
  ["Thiago Rezende",    "600.045.045-45"], ["Ursula Vaz",        "600.046.046-46"],
  ["Vinicius Abreu",    "600.047.047-47"], ["Wanda Leite",       "600.048.048-48"],
  ["Xavier Coelho",     "600.049.049-49"], ["Yasmin Castro",     "600.050.050-50"],
]

print "   Criando colaboradores... "
pool = colabs_data.map do |name, cpf|
  cpf_clean = cpf.gsub(/\D/, "")
  email     = "#{name.parameterize}@seed5.com"
  u = User.find_by(cpf: cpf_clean) || User.find_by(email: email)
  unless u
    u = User.new(cpf: cpf_clean, name: name, email: email,
                 role: collab_role, password: "senha123")
    u.save!(validate: false)
  end
  u.companies << company unless u.companies.include?(company)
  u
end
puts "#{pool.size} ✓"


# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURAÇÃO DOS 5 EVENTOS
#
# Cada setor define:
#   :members   → range de índices do pool (ex: 0..7 = 8 pessoas)
#   :functions → [[nome, valor_hora], ...]  — atribuídas em round-robin por membro
#   :shift     → ["HH:MM", "HH:MM"]        — início e fim do turno diário
#   :pay_ratio → fração dos membros que recebe pagamento (0.0 = nenhum)
# ═══════════════════════════════════════════════════════════════════════════════

events_config = [

  # ── 1. Festival Boombay 2025 (3 dias · 5 setores · 36 membros) ──────────────
  {
    name:            "Festival Boombay 2025",
    code:            "BBY25",
    event_type:      "festival",
    location:        "Belo Horizonte, MG",
    start_date:      Date.new(2025, 11, 14),
    end_date:        Date.new(2025, 11, 16),
    status:          "closed",
    event_day_hours: 14,
    sectors: [
      { name: "Palco",     sec_type: "stage",    team: "Equipe Palco",
        functions: [["Técnico de Som", 39.0], ["Roadie", 20.0]],
        members: (0..7),   shift: ["14:00", "23:00"], pay_ratio: 1.0 },

      { name: "Segurança", sec_type: "security", team: "Equipe Segurança",
        functions: [["Segurança", 14.0], ["Coord. de Segurança", 28.0]],
        members: (8..17),  shift: ["08:00", "20:00"], pay_ratio: 0.7 },

      { name: "Bar",       sec_type: "bar",      team: "Equipe Bar",
        functions: [["Bartender", 18.0], ["Garçom", 15.0]],
        members: (18..24), shift: ["16:00", "23:00"], pay_ratio: 0.6 },

      { name: "Limpeza",   sec_type: "cleaning", team: "Equipe Limpeza",
        functions: [["Agente de Limpeza", 12.0]],
        members: (25..30), shift: ["07:00", "16:00"], pay_ratio: 1.0 },

      { name: "Produção",  sec_type: "executive",team: "Equipe Produção",
        functions: [["Assistente de Produção", 30.0], ["Coordenador", 40.0]],
        members: (31..35), shift: ["10:00", "22:00"], pay_ratio: 1.0 },
    ],
  },

  # ── 2. Show Rock Nacional (1 dia · 3 setores · 23 membros) ──────────────────
  {
    name:            "Show Rock Nacional",
    code:            "SRN25",
    event_type:      "show",
    location:        "São Paulo, SP",
    start_date:      Date.new(2025, 10, 4),
    end_date:        Date.new(2025, 10, 4),
    status:          "closed",
    event_day_hours: 10,
    sectors: [
      { name: "Palco",     sec_type: "stage",    team: "Equipe Palco",
        functions: [["Técnico de Som", 39.0], ["Roadie", 20.0]],
        members: (0..7),   shift: ["15:00", "23:00"], pay_ratio: 1.0 },

      { name: "Segurança", sec_type: "security", team: "Equipe Segurança",
        functions: [["Segurança", 14.0]],
        members: (8..17),  shift: ["14:00", "23:00"], pay_ratio: 0.8 },

      { name: "Logística", sec_type: "logistics",team: "Equipe Logística",
        functions: [["Montador", 22.0], ["Motorista", 20.0]],
        members: (36..40), shift: ["08:00", "17:00"], pay_ratio: 1.0 },
    ],
  },

  # ── 3. Congresso de Inovação (2 dias · 4 setores · 26 membros) ──────────────
  {
    name:            "Congresso de Inovação",
    code:            "CNI25",
    event_type:      "conference",
    location:        "Rio de Janeiro, RJ",
    start_date:      Date.new(2025, 9, 18),
    end_date:        Date.new(2025, 9, 19),
    status:          "closed",
    event_day_hours: 14,
    sectors: [
      { name: "Recepção",    sec_type: "reception", team: "Equipe Recepção",
        functions: [["Recepcionista", 18.0], ["Host", 35.0]],
        members: (18..24),  shift: ["08:00", "18:00"], pay_ratio: 1.0 },

      { name: "Segurança",   sec_type: "security",  team: "Equipe Segurança",
        functions: [["Segurança", 14.0]],
        members: (41..46),  shift: ["07:00", "19:00"], pay_ratio: 0.5 },

      { name: "Audiovisual", sec_type: "sound",     team: "Equipe AV",
        functions: [["Técnico de AV", 35.0], ["Operador de Câmera", 30.0]],
        members: (25..29),  shift: ["09:00", "19:00"], pay_ratio: 1.0 },

      { name: "Catering",    sec_type: "catering",  team: "Equipe Catering",
        functions: [["Garçom", 15.0], ["Cozinheiro", 25.0]],
        members: (30..37),  shift: ["07:00", "20:00"], pay_ratio: 0.75 },
    ],
  },

  # ── 4. Corrida das Nações (1 dia · 3 setores · 22 membros) ──────────────────
  {
    name:            "Corrida das Nações",
    code:            "CDN25",
    event_type:      "race",
    location:        "Curitiba, PR",
    start_date:      Date.new(2025, 8, 23),
    end_date:        Date.new(2025, 8, 23),
    status:          "closed",
    event_day_hours: 12,
    sectors: [
      { name: "Segurança",      sec_type: "security", team: "Equipe Segurança",
        functions: [["Segurança", 14.0], ["Coord. de Segurança", 28.0]],
        members: (0..8),    shift: ["05:00", "14:00"], pay_ratio: 1.0 },

      { name: "Suporte Médico", sec_type: "health",   team: "Equipe Médica",
        functions: [["Socorrista", 35.0], ["Aux. de Enfermagem", 28.0]],
        members: (38..43),  shift: ["05:00", "14:00"], pay_ratio: 1.0 },

      { name: "Logística",      sec_type: "logistics",team: "Equipe Logística",
        functions: [["Montador", 22.0], ["Motorista", 20.0]],
        members: (9..15),   shift: ["04:00", "14:00"], pay_ratio: 0.7 },
    ],
  },

  # ── 5. Gala Empresarial 2026 (1 dia · 3 setores · 21 membros · ativo) ───────
  {
    name:            "Gala Empresarial 2026",
    code:            "GEP26",
    event_type:      "award_ceremony",
    location:        "Brasília, DF",
    start_date:      Date.today,
    end_date:        Date.today,
    status:          "active",
    event_day_hours: 10,
    sectors: [
      { name: "Recepção", sec_type: "reception", team: "Equipe Recepção",
        functions: [["Recepcionista", 18.0], ["Host", 35.0]],
        members: (9..16),  shift: ["17:00", "23:00"], pay_ratio: 0.0 },

      { name: "Palco",    sec_type: "stage",    team: "Equipe Palco",
        functions: [["Técnico de Som", 39.0], ["Iluminador", 35.0]],
        members: (17..22), shift: ["15:00", "23:00"], pay_ratio: 0.0 },

      { name: "Segurança",sec_type: "security", team: "Equipe Segurança",
        functions: [["Segurança", 14.0]],
        members: (23..29), shift: ["16:00", "23:00"], pay_ratio: 0.0 },
    ],
  },

]

# ═══════════════════════════════════════════════════════════════════════════════
# GERAÇÃO
# ═══════════════════════════════════════════════════════════════════════════════

events_config.each do |cfg|
  print "\n   [#{cfg[:code]}] #{cfg[:name].ljust(30)} "

  # ── Evento ────────────────────────────────────────────────────────────────────
  event = Event.find_or_initialize_by(code: cfg[:code])
  event.assign_attributes(
    name:       cfg[:name],
    company:    company,
    location:   cfg[:location],
    start_date: cfg[:start_date],
    end_date:   cfg[:end_date],
    status:     cfg[:status],
    event_type: cfg[:event_type]
  )
  event.save!(validate: false)

  # ── Dias do evento ─────────────────────────────────────────────────────────────
  (cfg[:start_date]..cfg[:end_date]).each do |date|
    ed = EventDay.find_or_initialize_by(event: event, date: date)
    ed.hours = cfg[:event_day_hours]
    ed.save!(validate: false)
  end

  num_days = (cfg[:end_date] - cfg[:start_date]).to_i + 1

  cfg[:sectors].each do |sc|
    members = pool[sc[:members]]

    # -- Funções do evento
    fns = sc[:functions].map do |fn_name, rate|
      ef = EventFunction.find_or_initialize_by(event: event, name: fn_name)
      ef.hourly_rate = rate
      ef.save!(validate: false)
      ef
    end

    # -- Setor
    sector = Sector.find_or_initialize_by(name: sc[:name], event: event)
    sector.sector_type = sc[:sec_type]
    sector.save!(validate: false)

    # -- Funções do setor (SectorFunction)
    fns.each do |ef|
      sf = SectorFunction.find_or_initialize_by(sector: sector, event_function: ef)
      sf.quantity = (members.size.to_f / fns.size).ceil if sf.new_record?
      sf.save!(validate: false)
    end

    # -- Equipe
    team = Team.find_or_initialize_by(name: sc[:team], sector: sector)
    team.save!(validate: false)
    team.update_columns(coordinator_id: members.first.id)

    # -- Memberships (round-robin de funções)
    members.each_with_index do |user, idx|
      ef = fns[idx % fns.size]
      m  = TeamMembership.find_or_initialize_by(team: team, user: user)
      m.role           = idx == 0 ? :coordinator : :member
      m.event_function = ef
      m.save!(validate: false)
      user.companies << company unless user.companies.include?(company)
    end

    # -- Escalas: 1 turno por membro por dia
    shift_start_str, shift_end_str = sc[:shift]
    (cfg[:start_date]..cfg[:end_date]).each do |date|
      members.each do |user|
        shift = Shift.find_or_initialize_by(user: user, sector: sector, team: team, date: date)
        if shift.new_record?
          shift.start_time = Time.parse("#{date} #{shift_start_str}")
          shift.end_time   = Time.parse("#{date} #{shift_end_str}")
          shift.save!(validate: false)
        end
      end
    end

    # -- Attendances
    if cfg[:status] == "closed"
      # Encerrado: check-in + check-out para ~88% dos membros, por dia
      (cfg[:start_date]..cfg[:end_date]).each do |date|
        members.each do |user|
          next if rand(100) < 12  # ~12% de ausência

          shift = Shift.find_by(user: user, sector: sector, team: team, date: date)
          next unless shift

          att = Attendance.find_or_initialize_by(user: user, event: event, checked_in_date: date)
          if att.new_record?
            att.team           = team
            att.checked_in_at  = shift.start_time + rand(1..12).minutes
            att.checked_out_at = shift.end_time   - rand(1..8).minutes
            att.checked_in_by  = admin
            att.checked_out_by = admin
            att.save!(validate: false)
          end
        end
      end

    elsif cfg[:status] == "active"
      # Ativo: ~55% dos membros com check-in hoje, sem checkout
      today = Date.today
      members.each do |user|
        next if rand(100) < 45  # ~45% ainda não chegaram

        att = Attendance.find_or_initialize_by(user: user, event: event, checked_in_date: today)
        if att.new_record?
          att.team          = team
          att.checked_in_at = Time.parse("#{today} #{shift_start_str}") + rand(1..20).minutes
          att.checked_in_by = admin
          att.save!(validate: false)
        end
      end
    end

    # -- Pagamentos (somente eventos encerrados, por pay_ratio)
    next unless cfg[:status] == "closed" && sc[:pay_ratio] > 0

    shift_hours = begin
      s = Time.parse("2000-01-01 #{shift_start_str}")
      e = Time.parse("2000-01-01 #{shift_end_str}")
      ((e - s) / 3600.0).round(1)
    end
    total_hours = (shift_hours * num_days).round(1)
    paid_at     = cfg[:end_date].to_time + 3.days
    pay_count   = (members.size * sc[:pay_ratio]).ceil

    members.first(pay_count).each do |user|
      ef = TeamMembership.find_by(team: team, user: user)&.event_function
      next unless ef&.hourly_rate.to_f > 0

      pay = Payment.find_or_initialize_by(event: event, user: user)
      if pay.new_record?
        pay.paid_by        = admin
        pay.paid_at        = paid_at
        pay.amount         = (ef.hourly_rate * total_hours).round(2)
        pay.hours          = total_hours
        pay.hourly_rate    = ef.hourly_rate
        pay.function_name  = ef.name
        pay.payment_method = %w[pix bank_transfer cash].sample
        pay.basis          = "cross"
        pay.save!(validate: false)
      end
    end

    print "."
  end

  puts " [#{cfg[:status]}] #{num_days}d · #{cfg[:sectors].size} setores · #{cfg[:sectors].sum { |s| pool[s[:members]].size }} membros"
end

# ═══════════════════════════════════════════════════════════════════════════════
# RESUMO
# ═══════════════════════════════════════════════════════════════════════════════

puts ""
puts "✓ Seed concluída!"
puts ""
puts "   Eventos     : #{Event.count}"
puts "     encerrados: #{Event.where(status: 'closed').count}"
puts "     ativos    : #{Event.where(status: 'active').count}"
puts "   Setores     : #{Sector.count}"
puts "   Equipes     : #{Team.count}"
puts "   Memberships : #{TeamMembership.count}"
puts "   Escalas     : #{Shift.count}"
puts "   Attendances : #{Attendance.count} (#{Attendance.where.not(checked_out_at: nil).count} com checkout)"
puts "   Pagamentos  : #{Payment.count}"
puts ""
puts "   Acesse: http://localhost:3000/events"
