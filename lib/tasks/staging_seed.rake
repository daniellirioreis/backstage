namespace :staging do
  desc "Cria dados de demonstração para testar o painel do coordenador"
  task seed_coordinator: :environment do
    puts "==> Criando dados de demo para painel do coordenador..."

    # Usa a primeira empresa existente
    company = Company.first
    abort "Nenhuma empresa encontrada. Crie uma empresa primeiro." unless company

    # Evento ativo hoje
    event = Event.find_or_initialize_by(name: "[DEMO] Festival Mobile Test")
    event.assign_attributes(
      company:    company,
      status:     "active",
      start_date: Date.today,
      end_date:   Date.today + 2.days,
      location:   "Praça da Liberdade, BH"
    )
    event.save!
    puts "   Evento: #{event.name} (#{event.status})"

    # Função no evento
    func = event.event_functions.find_or_create_by!(name: "Segurança") do |f|
      f.hourly_rate = 25.0
    end

    # Setor
    sector = event.sectors.find_or_create_by!(name: "Portaria Principal") do |s|
      s.sector_type      = "security"
      s.planned_headcount = 5
    end

    # Equipe
    team = sector.teams.find_or_create_by!(name: "Equipe Alpha")
    puts "   Equipe: #{team.name}"

    # Pega ou cria até 5 usuários de teste
    users = User.limit(5).to_a
    if users.size < 3
      abort "Precisa de pelo menos 3 usuários cadastrados no sistema."
    end

    # Limpa membros anteriores da equipe demo para recriar
    team.team_memberships.destroy_all

    # Membro 1: coordenador
    coord = team.team_memberships.create!(
      user:           users[0],
      role:           :coordinator,
      event_function: func
    )
    puts "   Coordenador: #{users[0].name}"

    # Membros 2–5
    members = users[1..4].map do |u|
      team.team_memberships.create!(
        user:           u,
        role:           :member,
        event_function: func
      )
    end

    # Shifts de hoje para todos os membros
    all_members = [coord] + members
    all_members.each do |tm|
      Shift.find_or_create_by!(
        user:   tm.user,
        sector: sector,
        team:   team,
        date:   Date.today
      ) do |s|
        s.start_time = Time.zone.parse("08:00")
        s.end_time   = Time.zone.parse("18:00")
      end
    end
    puts "   Shifts criados para #{all_members.size} membros"

    # Presenças simuladas:
    # - coord + membro[0]: check-in E check-out (presente)
    # - membro[1]: só check-in (em atividade)
    # - membro[2]: sem check-in (ausente)
    # - membro[3]: sem check-in (ausente) — se existir

    presentes  = [users[0], users[1]]
    em_ativ    = [users[2]]

    presentes.each do |u|
      att = Attendance.find_or_initialize_by(
        user:             u,
        event:            event,
        checked_in_date:  Date.today
      )
      unless att.persisted?
        att.checked_in_at  = Time.zone.now - 4.hours
        att.checked_in_by  = users[0]
        att.checked_out_at = Time.zone.now - 1.hour
        att.source         = :manual
        att.save!
      end
    end

    em_ativ.each do |u|
      att = Attendance.find_or_initialize_by(
        user:            u,
        event:           event,
        checked_in_date: Date.today
      )
      unless att.persisted?
        att.checked_in_at = Time.zone.now - 2.hours
        att.checked_in_by = users[0]
        att.source        = :manual
        att.save!
      end
    end

    puts "   Presenças: #{presentes.size} presentes, #{em_ativ.size} em atividade, #{(all_members.size - presentes.size - em_ativ.size)} ausentes"
    puts ""
    puts "==> Concluído!"
    puts ""
    puts "   Acesse o painel em:"
    puts "   https://backstage-staging-6j0k.onrender.com/teams/#{team.id}/panel"
    puts ""
    puts "   Login como #{users[0].email} para ver a visão de coordenador."
  end
end
