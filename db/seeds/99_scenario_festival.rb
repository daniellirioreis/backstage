# Seed de cenário completo: Festival Horizonte 2026
# Cria evento encerrado com múltiplos setores, funções, escalas e situações variadas:
#   - Colaboradores presentes e pagos
#   - Colaboradores presentes e NÃO pagos (a pagar)
#   - Colaboradores ausentes (escalados mas sem presença)
#   - Colaborador com check-in sem checkout (pendente)
#   - Colaborador com presença mas sem escala (não escalado)
#
# Uso: docker compose exec web rails runner db/seeds/99_scenario_festival.rb

puts "\n→ Festival Horizonte 2026 — seed de cenário completo"

company = Company.first || Company.create!(name: "Produtora Horizonte")
admin   = User.joins(:role).where(roles: { name: "admin" }).first

# ── Evento ────────────────────────────────────────────────────────────────────
event = Event.find_or_create_by!(name: "Festival Horizonte 2026") do |e|
  e.company    = company
  e.location   = "São Paulo, SP"
  e.start_date = Date.new(2026, 5, 9)
  e.end_date   = Date.new(2026, 5, 10)
  e.status     = "closed"
  e.code       = "FH26"
  e.event_type = "festival"
end
event.update!(status: "closed") unless event.closed?
event.update_columns(event_type: "festival") if event.event_type.blank?
puts "   Evento: #{event.name} (#{event.status})"

# ── Dias do evento ────────────────────────────────────────────────────────────
[
  { date: Date.new(2026, 5, 9),  hours: 14 },
  { date: Date.new(2026, 5, 10), hours: 14 }
].each do |d|
  EventDay.find_or_create_by!(event: event, date: d[:date]) { |ed| ed.hours = d[:hours] }
  EventDay.where(event: event, date: d[:date]).update_all(hours: d[:hours])
end

# ── Funções do evento ─────────────────────────────────────────────────────────
functions_rates = {
  "Técnico de Som"        => 39.0,
  "Técnico de Iluminação" => 39.0,
  "Segurança"             => 14.0,
  "Agente de Limpeza"     => 20.0,
  "Atendente de Bar"      => 7.0,
  "Caixa de Bilheteria"   => 7.5,
  "Roadie"                => 20.0,
}

fn = {}
functions_rates.each do |name, rate|
  catalog_rate = EventFunction.find_by(event_id: nil, name: name)&.hourly_rate || rate
  fn[name] = EventFunction.find_or_create_by!(event: event, name: name) { |f| f.hourly_rate = catalog_rate }
  fn[name].update!(hourly_rate: catalog_rate)
end
puts "   Funções: #{fn.size}"

# ── Setores + sector_functions ────────────────────────────────────────────────
sectors_data = {
  "Palco"      => { "Técnico de Som" => 1, "Técnico de Iluminação" => 1, "Roadie" => 2 },
  "Segurança"  => { "Segurança" => 4 },
  "Bar"        => { "Atendente de Bar" => 3 },
  "Limpeza"    => { "Agente de Limpeza" => 3 },
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
collaborator_role = Role.find_by!(name: "colaborador")

def make_user(name, cpf, role, company)
  cpf_clean = cpf.gsub(/\D/, "")
  email     = "#{name.downcase.gsub(/\s+/, '.').parameterize}@fh26.com"
  u = User.find_by(cpf: cpf_clean) || User.find_by(email: email)
  unless u
    u = User.new(cpf: cpf_clean, name: name, email: email,
                 role: role, password: "senha123")
    u.save!(validate: false)
    u.companies << company unless u.companies.include?(company)
  end
  u
end

colabs = {
  # Palco
  tecsom:    make_user("Rafael Cunha",      "301.111.111-01", collaborator_role, company),
  tecilu:    make_user("Beatriz Fontes",    "302.222.222-02", collaborator_role, company),
  roadie1:   make_user("Lucas Drummond",    "303.333.333-03", collaborator_role, company),
  roadie2:   make_user("Ana Silveira",      "304.444.444-04", collaborator_role, company),
  # Segurança
  seg1:      make_user("Carlos Menezes",    "305.555.555-05", collaborator_role, company),
  seg2:      make_user("Patrícia Rocha",    "306.666.666-06", collaborator_role, company),
  seg3:      make_user("Thiago Bastos",     "307.777.777-07", collaborator_role, company),
  seg4:      make_user("Fernanda Lima",     "308.888.888-08", collaborator_role, company),
  # Bar
  bar1:      make_user("Mariana Castro",    "309.999.999-09", collaborator_role, company),
  bar2:      make_user("Diego Alves",       "310.111.222-10", collaborator_role, company),
  bar3:      make_user("Juliana Pires",     "311.222.333-11", collaborator_role, company),
  # Limpeza
  limp1:     make_user("Cleide Souza",      "312.333.444-12", collaborator_role, company),
  limp2:     make_user("Marcos Ferreira",   "313.444.555-13", collaborator_role, company),
  limp3:     make_user("Sandra Oliveira",   "314.555.666-14", collaborator_role, company),
  # Bilheteria
  caixa1:    make_user("Roberta Mendes",    "315.666.777-15", collaborator_role, company),
  caixa2:    make_user("André Cardoso",     "316.777.888-16", collaborator_role, company),
  # Extra: colaborador sem escala (vai aparecer como "não escalado")
  extra:     make_user("Paulo Extra",       "317.888.999-17", collaborator_role, company),
}
puts "   Colaboradores: #{colabs.size}"

# ── Equipes + memberships ─────────────────────────────────────────────────────
# Coordenador é setado via Team#coordinator_id; o callback sync_coordinator_membership
# cria automaticamente um TeamMembership com role: :coordinator.
def add_team(name, sector, coordinator, members_with_fn)
  team = Team.find_or_create_by!(name: name, sector: sector)
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
  palco:      add_team("Equipe Palco",      sectors["Palco"],      colabs[:tecsom], [
                [colabs[:tecilu],  fn["Técnico de Iluminação"]],
                [colabs[:roadie1], fn["Roadie"]],
                [colabs[:roadie2], fn["Roadie"]],
              ]),
  seguranca:  add_team("Equipe Segurança",  sectors["Segurança"],  colabs[:seg1], [
                [colabs[:seg2], fn["Segurança"]],
                [colabs[:seg3], fn["Segurança"]],
                [colabs[:seg4], fn["Segurança"]],
              ]),
  bar:        add_team("Equipe Bar",        sectors["Bar"],        colabs[:bar1], [
                [colabs[:bar2], fn["Atendente de Bar"]],
                [colabs[:bar3], fn["Atendente de Bar"]],
              ]),
  limpeza:    add_team("Equipe Limpeza",    sectors["Limpeza"],    colabs[:limp1], [
                [colabs[:limp2], fn["Agente de Limpeza"]],
                [colabs[:limp3], fn["Agente de Limpeza"]],
              ]),
  bilheteria: add_team("Equipe Bilheteria", sectors["Bilheteria"], colabs[:caixa1], [
                [colabs[:caixa2], fn["Caixa de Bilheteria"]],
              ]),
}
puts "   Equipes: #{teams.size}"

# ── Escalas (2 dias, todos os colaboradores exceto :extra) ───────────────────
shift_specs = [
  # [team_key, user_key, date_offset, start, end]
  [:palco,      :tecsom,  0, "14:00", "23:00"],
  [:palco,      :tecsom,  1, "14:00", "23:00"],
  [:palco,      :tecilu,  0, "14:00", "23:00"],
  [:palco,      :tecilu,  1, "14:00", "23:00"],
  [:palco,      :roadie1, 0, "10:00", "22:00"],
  [:palco,      :roadie1, 1, "10:00", "22:00"],
  [:palco,      :roadie2, 0, "10:00", "22:00"],
  [:palco,      :roadie2, 1, "10:00", "22:00"],
  [:seguranca,  :seg1,    0, "12:00", "23:00"],
  [:seguranca,  :seg1,    1, "12:00", "23:00"],
  [:seguranca,  :seg2,    0, "12:00", "23:00"],
  [:seguranca,  :seg2,    1, "12:00", "23:00"],
  [:seguranca,  :seg3,    0, "12:00", "23:00"],  # ausente no dia 2
  [:seguranca,  :seg4,    0, "12:00", "22:00"],  # ausente em ambos os dias
  [:seguranca,  :seg4,    1, "12:00", "22:00"],
  [:bar,        :bar1,    0, "16:00", "23:00"],
  [:bar,        :bar1,    1, "16:00", "23:00"],
  [:bar,        :bar2,    0, "16:00", "23:00"],
  [:bar,        :bar2,    1, "16:00", "23:00"],
  [:bar,        :bar3,    0, "16:00", "23:00"],  # só no dia 1
  [:limpeza,    :limp1,   0, "08:00", "16:00"],
  [:limpeza,    :limp1,   1, "08:00", "16:00"],
  [:limpeza,    :limp2,   0, "08:00", "16:00"],
  [:limpeza,    :limp2,   1, "08:00", "16:00"],
  [:limpeza,    :limp3,   0, "08:00", "16:00"],
  [:limpeza,    :limp3,   1, "08:00", "16:00"],
  [:bilheteria, :caixa1,  0, "10:00", "20:00"],
  [:bilheteria, :caixa1,  1, "10:00", "20:00"],
  [:bilheteria, :caixa2,  0, "10:00", "20:00"],
  [:bilheteria, :caixa2,  1, "10:00", "20:00"],
]

base_date = event.start_date
shift_specs.each do |team_key, user_key, offset, start_t, end_t|
  date = base_date + offset.days
  Shift.find_or_create_by!(
    user:       colabs[user_key],
    sector:     teams[team_key].sector,
    team:       teams[team_key],
    date:       date,
    start_time: Time.parse("#{date} #{start_t}"),
    end_time:   Time.parse("#{date} #{end_t}")
  )
end
puts "   Escalas: #{Shift.joins(:sector).where(sectors: { event: event }).count}"

# ── Attendances ───────────────────────────────────────────────────────────────
Attendance.where(event: event).destroy_all

def att(event, user, team, date, cin, cout, admin)
  Attendance.create!(
    event:          event,
    user:           user,
    team:           team,
    checked_in_at:  Time.parse("#{date} #{cin}"),
    checked_out_at: cout ? Time.parse("#{date} #{cout}") : nil,
    checked_in_by:  admin,
    checked_out_by: cout ? admin : nil,
    checked_in_date: date
  )
end

d0 = base_date
d1 = base_date + 1.day

# Palco — todos presentes, ambos os dias
att(event, colabs[:tecsom],  teams[:palco], d0, "14:08", "22:55", admin)
att(event, colabs[:tecsom],  teams[:palco], d1, "14:03", "23:02", admin)
att(event, colabs[:tecilu],  teams[:palco], d0, "14:12", "22:58", admin)
att(event, colabs[:tecilu],  teams[:palco], d1, "14:05", "23:00", admin)
att(event, colabs[:roadie1], teams[:palco], d0, "10:15", "21:50", admin)
att(event, colabs[:roadie1], teams[:palco], d1, "10:07", "22:05", admin)
att(event, colabs[:roadie2], teams[:palco], d0, "10:20", "22:00", admin)
att(event, colabs[:roadie2], teams[:palco], d1, "10:10", "21:55", admin)

# Segurança — seg3 ausente no dia 2, seg4 ausente em ambos os dias
att(event, colabs[:seg1], teams[:seguranca], d0, "12:05", "23:00", admin)
att(event, colabs[:seg1], teams[:seguranca], d1, "12:10", "23:05", admin)
att(event, colabs[:seg2], teams[:seguranca], d0, "12:00", "22:55", admin)
att(event, colabs[:seg2], teams[:seguranca], d1, "12:08", "23:00", admin)
att(event, colabs[:seg3], teams[:seguranca], d0, "12:03", "22:58", admin)
# seg3 não compareceu no dia 2 — sem attendance
# seg4 não compareceu em nenhum dia — sem attendance

# Bar — bar3 com checkout pendente no dia 1
att(event, colabs[:bar1], teams[:bar], d0, "16:05", "23:00", admin)
att(event, colabs[:bar1], teams[:bar], d1, "16:02", "22:58", admin)
att(event, colabs[:bar2], teams[:bar], d0, "16:08", "23:02", admin)
att(event, colabs[:bar2], teams[:bar], d1, "16:00", "23:05", admin)
att(event, colabs[:bar3], teams[:bar], d0, "16:10", nil,     admin)  # checkout pendente

# Limpeza — todos presentes
att(event, colabs[:limp1], teams[:limpeza], d0, "08:05", "16:02", admin)
att(event, colabs[:limp1], teams[:limpeza], d1, "08:10", "15:58", admin)
att(event, colabs[:limp2], teams[:limpeza], d0, "08:02", "16:05", admin)
att(event, colabs[:limp2], teams[:limpeza], d1, "08:07", "16:03", admin)
att(event, colabs[:limp3], teams[:limpeza], d0, "08:15", "15:55", admin)
att(event, colabs[:limp3], teams[:limpeza], d1, "08:08", "16:00", admin)

# Bilheteria — todos presentes
att(event, colabs[:caixa1], teams[:bilheteria], d0, "10:05", "19:55", admin)
att(event, colabs[:caixa1], teams[:bilheteria], d1, "10:03", "20:02", admin)
att(event, colabs[:caixa2], teams[:bilheteria], d0, "10:10", "20:00", admin)
att(event, colabs[:caixa2], teams[:bilheteria], d1, "10:08", "19:58", admin)

# Extra — presença sem escala (não escalado)
att(event, colabs[:extra], teams[:bar], d0, "16:00", "22:00", admin)

puts "   Attendances: #{Attendance.where(event: event).count}"

# ── Pagamentos (parcial — alguns pagos, alguns pendentes) ─────────────────────
Payment.where(event: event).destroy_all

def pay(event, user, amount, hours, rate, fn_name, admin)
  Payment.create!(
    event:          event,
    user:           user,
    paid_by:        admin,
    paid_at:        Time.current,
    amount:         amount,
    hours:          hours,
    hourly_rate:    rate,
    function_name:  fn_name,
    payment_method: %w[pix bank_transfer cash].sample,
    basis:          "cross"
  )
end

# Pagos: palco completo + limpeza completa + caixa1
pay(event, colabs[:tecsom],  39.0 * 18, 18, 39.0, "Técnico de Som",        admin)
pay(event, colabs[:tecilu],  39.0 * 18, 18, 39.0, "Técnico de Iluminação", admin)
pay(event, colabs[:roadie1], 20.0 * 24, 24, 20.0, "Roadie",                admin)
pay(event, colabs[:roadie2], 20.0 * 24, 24, 20.0, "Roadie",                admin)
pay(event, colabs[:limp1],   20.0 * 16, 16, 20.0, "Agente de Limpeza",     admin)
pay(event, colabs[:limp2],   20.0 * 16, 16, 20.0, "Agente de Limpeza",     admin)
pay(event, colabs[:limp3],   20.0 * 16, 16, 20.0, "Agente de Limpeza",     admin)
pay(event, colabs[:caixa1],  7.5  * 20, 20,  7.5, "Caixa de Bilheteria",   admin)

# Não pagos ainda: seg1, seg2, seg3, bar1, bar2, caixa2
# (seg4, bar3 e extra ficam em situação irregular)

puts "   Pagamentos: #{Payment.where(event: event).count}"

puts ""
puts "✓ Cenário criado com sucesso!"
puts ""
puts "  Situações geradas:"
puts "  ✅ Presentes e pagos   : Técnicos de Som/Ilum, Roadies, Limpeza (3), Caixa1"
puts "  ⏳ Presentes não pagos : Segurança (seg1, seg2, seg3 dia1), Bar (bar1, bar2), Caixa2"
puts "  ❌ Ausentes            : Segurança (seg3 dia2, seg4 ambos dias)"
puts "  🕐 Checkout pendente   : Bar3 (check-in sem check-out)"
puts "  ⚠️  Não escalado        : Paulo Extra (presença sem escala)"
puts ""
puts "  Acesse: http://localhost:3000/events"
puts "  Selecione 'Festival Horizonte 2026' e vá em Fechamento > Cruzamento"
