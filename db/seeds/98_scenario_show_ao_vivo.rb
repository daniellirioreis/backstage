# Seed de cenário: Show ao Vivo 2026 — evento ativo com check-ins em andamento
#
# Situações geradas:
#   - Colaboradores com check-in SEM checkout (dentro agora)
#   - Colaboradores com check-in E checkout (já saíram)
#   - Colaboradores ainda não entraram (sem attendance)
#
# Uso: docker compose exec web rails runner db/seeds/98_scenario_show_ao_vivo.rb

puts "\n→ Show ao Vivo 2026 — seed de cenário evento ativo"

company = Company.first || Company.create!(name: "Produtora Horizonte")
admin   = User.joins(:role).where(roles: { name: "admin" }).first
abort "Admin não encontrado." unless admin

collaborator_role = Role.find_by!(name: "colaborador")

# ── Evento ────────────────────────────────────────────────────────────────────
event = Event.find_or_create_by!(name: "Show ao Vivo 2026") do |e|
  e.company    = company
  e.location   = "Belo Horizonte, MG"
  e.start_date = Date.today
  e.end_date   = Date.today
  e.status     = "active"
  e.code       = "SAV26"
  e.event_type = "show"
end
event.update!(status: "active") unless event.active?
event.update_columns(event_type: "show") if event.event_type.blank?
puts "   Evento: #{event.name} (#{event.status})"

# ── Dia do evento ─────────────────────────────────────────────────────────────
ed = EventDay.find_or_initialize_by(event: event, date: Date.today)
ed.hours = 14
ed.save!
EventDay.where(event: event, date: Date.today).update_all(hours: 14)

# ── Funções do evento ─────────────────────────────────────────────────────────
functions_rates = {
  "Técnico de Som"      => 39.0,
  "Segurança"           => 14.0,
  "Atendente de Bar"    => 7.0,
  "Agente de Limpeza"   => 20.0,
  "Caixa de Bilheteria" => 7.5,
}

fn = {}
functions_rates.each do |name, rate|
  fn[name] = EventFunction.find_or_create_by!(event: event, name: name) { |f| f.hourly_rate = rate }
  fn[name].update!(hourly_rate: rate)
end
puts "   Funções: #{fn.size}"

# ── Setores + sector_functions ────────────────────────────────────────────────
sectors_data = {
  "Palco"      => { "Técnico de Som" => 2 },
  "Segurança"  => { "Segurança" => 3 },
  "Bar"        => { "Atendente de Bar" => 3 },
  "Limpeza"    => { "Agente de Limpeza" => 2 },
  "Bilheteria" => { "Caixa de Bilheteria" => 2 },
}

sectors = {}
sectors_data.each do |sector_name, fns|
  s = Sector.find_or_create_by!(name: sector_name, event: event)
  fns.each do |fn_name, qty|
    SectorFunction.find_or_create_by!(sector: s, event_function: fn[fn_name]) { |sf| sf.quantity = qty }
  end
  sectors[sector_name] = s
end
puts "   Setores: #{sectors.size}"

# ── Colaboradores ─────────────────────────────────────────────────────────────
def make_collab(name, cpf, role, company)
  cpf_clean = cpf.gsub(/\D/, "")
  u = User.find_or_initialize_by(cpf: cpf_clean)
  if u.new_record?
    u.name     = name
    u.email    = "#{name.downcase.gsub(/\s+/, '.').parameterize}@sav26.com"
    u.role     = role
    u.password = "senha123"
    u.save!(validate: false)
    u.companies << company unless u.companies.include?(company)
  end
  u
end

colabs = {
  # Palco
  som1:    make_collab("Felipe Andrade",    "401.111.111-01", collaborator_role, company),
  som2:    make_collab("Renata Vieira",     "402.222.222-02", collaborator_role, company),
  # Segurança
  seg1:    make_collab("Marcos Teixeira",   "403.333.333-03", collaborator_role, company),
  seg2:    make_collab("Aline Correia",     "404.444.444-04", collaborator_role, company),
  seg3:    make_collab("Bruno Nascimento",  "405.555.555-05", collaborator_role, company),
  # Bar
  bar1:    make_collab("Camila Duarte",     "406.666.666-06", collaborator_role, company),
  bar2:    make_collab("Rodrigo Faria",     "407.777.777-07", collaborator_role, company),
  bar3:    make_collab("Tatiane Moura",     "408.888.888-08", collaborator_role, company),
  # Limpeza
  limp1:   make_collab("José Carvalho",     "409.999.999-09", collaborator_role, company),
  limp2:   make_collab("Irene Machado",     "410.111.222-10", collaborator_role, company),
  # Bilheteria
  caixa1:  make_collab("Luciana Soares",    "411.222.333-11", collaborator_role, company),
  caixa2:  make_collab("Eduardo Pinto",     "412.333.444-12", collaborator_role, company),
}
puts "   Colaboradores: #{colabs.size}"

# ── Equipes + memberships ─────────────────────────────────────────────────────
# Coordenador é setado via Team#coordinator_id; o callback sync_coordinator_membership
# cria automaticamente um TeamMembership com role: :coordinator.
def add_team(name, sector, coordinator, members_with_fn)
  team = Team.find_or_create_by!(name: name, sector: sector)
  # Atualiza coordenador (dispara sync_coordinator_membership via after_save)
  team.update!(coordinator: coordinator) if coordinator && team.coordinator_id != coordinator.id
  members_with_fn.each do |user, ef|
    m = TeamMembership.find_or_initialize_by(team: team, user: user)
    m.role = :member
    m.event_function = ef if ef
    m.save! if m.new_record? || m.changed?
  end
  team
end

teams = {
  palco:      add_team("Equipe Palco",      sectors["Palco"],      colabs[:som1], [
                [colabs[:som2],  fn["Técnico de Som"]],
              ]),
  seguranca:  add_team("Equipe Segurança",  sectors["Segurança"],  colabs[:seg1], [
                [colabs[:seg2], fn["Segurança"]],
                [colabs[:seg3], fn["Segurança"]],
              ]),
  bar:        add_team("Equipe Bar",        sectors["Bar"],        colabs[:bar1], [
                [colabs[:bar2], fn["Atendente de Bar"]],
                [colabs[:bar3], fn["Atendente de Bar"]],
              ]),
  limpeza:    add_team("Equipe Limpeza",    sectors["Limpeza"],    colabs[:limp1], [
                [colabs[:limp2], fn["Agente de Limpeza"]],
              ]),
  bilheteria: add_team("Equipe Bilheteria", sectors["Bilheteria"], colabs[:caixa1], [
                [colabs[:caixa2], fn["Caixa de Bilheteria"]],
              ]),
}
puts "   Equipes: #{teams.size}"

# ── Escalas (hoje) ────────────────────────────────────────────────────────────
# Coordenadores agora têm escala própria como qualquer membro
shift_specs = [
  # Palco: som1 = coordenador, som2 = membro
  [:palco,      :som1,   "10:00", "22:00"],
  [:palco,      :som2,   "10:00", "22:00"],
  # Segurança: seg1 = coordenador, seg2/seg3 = membros
  [:seguranca,  :seg1,   "12:00", "23:00"],
  [:seguranca,  :seg2,   "12:00", "23:00"],
  [:seguranca,  :seg3,   "12:00", "23:00"],
  # Bar: bar1 = coordenador, bar2/bar3 = membros
  [:bar,        :bar1,   "16:00", "23:00"],
  [:bar,        :bar2,   "16:00", "23:00"],
  [:bar,        :bar3,   "16:00", "23:00"],
  # Limpeza: limp1 = coordenador, limp2 = membro
  [:limpeza,    :limp1,  "08:00", "20:00"],
  [:limpeza,    :limp2,  "08:00", "20:00"],
  # Bilheteria: caixa1 = coordenador, caixa2 = membro
  [:bilheteria, :caixa1, "10:00", "20:00"],
  [:bilheteria, :caixa2, "10:00", "20:00"],
]

today = Date.today
shift_specs.each do |team_key, user_key, start_t, end_t|
  Shift.find_or_create_by!(
    user:       colabs[user_key],
    sector:     teams[team_key].sector,
    team:       teams[team_key],
    date:       today,
    start_time: Time.parse("#{today} #{start_t}"),
    end_time:   Time.parse("#{today} #{end_t}")
  )
end
puts "   Escalas: #{Shift.joins(:sector).where(sectors: { event: event }).count}"

# ── Attendances ───────────────────────────────────────────────────────────────
Attendance.where(event: event).destroy_all

now = Time.current

# ✅ Palco — check-in E checkout (já saíram)
Attendance.create!(event: event, user: colabs[:som1],  team: teams[:palco],
  checked_in_at: now - 9.hours, checked_out_at: now - 1.hour,
  checked_in_date: today, checked_in_by: admin, checked_out_by: admin)

Attendance.create!(event: event, user: colabs[:som2],  team: teams[:palco],
  checked_in_at: now - 8.5.hours, checked_out_at: now - 30.minutes,
  checked_in_date: today, checked_in_by: admin, checked_out_by: admin)

# 🟢 Segurança — check-in SEM checkout (dentro agora)
Attendance.create!(event: event, user: colabs[:seg1], team: teams[:seguranca],
  checked_in_at: now - 5.hours - 10.minutes,
  checked_in_date: today, checked_in_by: admin)

Attendance.create!(event: event, user: colabs[:seg2], team: teams[:seguranca],
  checked_in_at: now - 4.hours - 45.minutes,
  checked_in_date: today, checked_in_by: admin)

# seg3 — ainda não entrou (sem attendance)

# 🟢 Bar — bar1 e bar2 dentro agora, bar3 ainda não entrou
Attendance.create!(event: event, user: colabs[:bar1], team: teams[:bar],
  checked_in_at: now - 2.hours - 20.minutes,
  checked_in_date: today, checked_in_by: admin)

Attendance.create!(event: event, user: colabs[:bar2], team: teams[:bar],
  checked_in_at: now - 2.hours,
  checked_in_date: today, checked_in_by: admin)

# bar3 — ainda não entrou (sem attendance)

# ✅ Limpeza — check-in E checkout (já saíram)
Attendance.create!(event: event, user: colabs[:limp1], team: teams[:limpeza],
  checked_in_at: now - 11.hours, checked_out_at: now - 3.hours,
  checked_in_date: today, checked_in_by: admin, checked_out_by: admin)

# limp2 — ainda não entrou (sem attendance)

# 🟢 Bilheteria — caixa1 dentro agora, caixa2 ainda não entrou
Attendance.create!(event: event, user: colabs[:caixa1], team: teams[:bilheteria],
  checked_in_at: now - 6.hours - 15.minutes,
  checked_in_date: today, checked_in_by: admin)

# caixa2 — ainda não entrou (sem attendance)

att_count = Attendance.where(event: event).count
puts "   Attendances: #{att_count}"

puts ""
puts "✓ Cenário criado com sucesso!"
puts ""
puts "  Situações geradas:"
puts "  ✅ Check-in + checkout (já saíram) : som1, som2, limp1"
puts "  🟢 Dentro agora (sem checkout)     : seg1, seg2, bar1, bar2, caixa1"
puts "  ⏳ Ainda não entraram              : seg3, bar3, limp2, caixa2"
puts ""
puts "  Acesse: http://localhost:3000/attendances"
