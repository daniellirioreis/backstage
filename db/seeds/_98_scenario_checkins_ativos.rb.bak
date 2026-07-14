# Seed de cenário: evento ativo com check-ins em andamento (sem checkout)
# Simula um evento acontecendo agora — colaboradores dentro do evento
#
# Uso: docker compose exec web rails runner db/seeds/98_scenario_checkins_ativos.rb

puts "\n→ Cenário: check-ins ativos no Boombay 2026"

event = Event.find_by!(name: "Boombay 2026")
abort "Evento não encontrado." unless event
abort "Evento não está ativo (status: #{event.status})" unless event.active?

admin = User.joins(:role).where(roles: { name: "admin" }).first

# Pega colaboradores com escalas no evento
shifts = Shift.joins(team: :sector)
              .where(sectors: { event_id: event.id })
              .includes(:user, :team)

abort "Nenhuma escala encontrada." if shifts.empty?

# Limpa attendances de hoje para não duplicar
Attendance.where(event: event, checked_in_date: Date.today).destroy_all

by_user = shifts.group_by(&:user_id).to_a.shuffle
total   = by_user.size

# 60% dentro agora (check-in sem checkout)
# 25% já saíram (check-in + checkout)
# 15% ainda não entraram (sem attendance)
inside_ids    = by_user.first((total * 0.60).ceil).map(&:first)
checked_out   = by_user[(total * 0.60).ceil..(total * 0.85).ceil - 1]&.map(&:first) || []

created_in  = 0
created_out = 0

by_user.each do |user_id, user_shifts|
  shift = user_shifts.first
  next unless shift

  if inside_ids.include?(user_id)
    # Dentro agora — check-in há algumas horas, sem checkout
    cin = Time.current - rand(1..4).hours - rand(0..45).minutes
    Attendance.create!(
      event:           event,
      user_id:         user_id,
      team:            shift.team,
      checked_in_at:   cin,
      checked_in_date: Date.today,
      checked_in_by:   admin
    )
    created_in += 1

  elsif checked_out.include?(user_id)
    # Já saiu — check-in e checkout completos
    cin  = Time.current - rand(3..6).hours - rand(0..30).minutes
    cout = cin + rand(2..4).hours + rand(0..30).minutes
    Attendance.create!(
      event:           event,
      user_id:         user_id,
      team:            shift.team,
      checked_in_at:   cin,
      checked_out_at:  cout,
      checked_in_date: Date.today,
      checked_in_by:   admin,
      checked_out_by:  admin
    )
    created_out += 1
  end
  # os demais (15%) ficam sem attendance — ainda não entraram
end

total_no_checkin = total - created_in - created_out

puts ""
puts "✓ Criados para o Boombay 2026 (hoje, #{Date.today.strftime('%d/%m/%Y')}):"
puts "  🟢 Dentro agora (sem checkout) : #{created_in}"
puts "  ✅ Já saíram (com checkout)    : #{created_out}"
puts "  ⏳ Ainda não entraram          : #{total_no_checkin}"
puts ""
puts "  Acesse: http://localhost:3000/attendances"
