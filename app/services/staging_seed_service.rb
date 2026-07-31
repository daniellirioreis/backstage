class StagingSeedService
  def self.run_coordinator_demo
    new.run
  end

  def run
    @log = []

    company = Company.first
    return "ERRO: Nenhuma empresa encontrada." unless company

    users = User.order(:id).limit(6).to_a
    return "ERRO: Precisa de pelo menos 3 usuários." if users.size < 3

    # Evento ativo
    event = Event.find_or_initialize_by(name: "[DEMO] Painel Coordenador")
    event.assign_attributes(
      company:    company,
      status:     "active",
      event_type: "festival",
      start_date: Date.today,
      end_date:   Date.today + 1.day,
      location:   "Praça da Liberdade, BH"
    )
    event.save!
    log "Evento: #{event.name} (id=#{event.id})"

    # Função
    func = event.event_functions.find_or_create_by!(name: "Geral") { |f| f.hourly_rate = 20.0 }

    # Setor
    sector = event.sectors.find_or_create_by!(name: "Portaria Demo") do |s|
      s.sector_type       = "security"
      s.planned_headcount = users.size
    end

    # Equipe
    team = sector.teams.find_or_create_by!(name: "Equipe Demo Mobile")
    log "Equipe: #{team.name} (id=#{team.id})"

    # Limpa membros anteriores
    team.team_memberships.destroy_all

    # Cria membros
    all_tm = users.each_with_index.map do |u, i|
      team.team_memberships.create!(
        user:           u,
        role:           i == 0 ? :coordinator : :member,
        event_function: func
      )
    end
    log "Membros: #{all_tm.size} (1 coordenador + #{all_tm.size - 1} membros)"

    # Shifts de hoje
    all_tm.each do |tm|
      Shift.find_or_create_by!(user: tm.user, sector: sector, team: team, date: Date.today) do |s|
        s.start_time = Time.zone.parse("08:00")
        s.end_time   = Time.zone.parse("18:00")
      end
    end
    log "Shifts criados para hoje (#{Date.today})"

    # Limpeza de presenças antigas do evento
    Attendance.where(event: event).destroy_all

    # Presente (check-in + check-out): usuários 0 e 1
    [users[0], users[1]].each do |u|
      Attendance.create!(
        user:            u,
        event:           event,
        checked_in_at:   Time.zone.now - 4.hours,
        checked_out_at:  Time.zone.now - 30.minutes,
        checked_in_date: Date.today,
        source:          :manual
      )
    end
    log "Presentes (check-in+out): #{users[0].name}, #{users[1].name}"

    # Em atividade (só check-in): usuário 2
    Attendance.create!(
      user:            users[2],
      event:           event,
      checked_in_at:   Time.zone.now - 1.hour,
      checked_in_date: Date.today,
      source:          :manual
    )
    log "Em atividade (só check-in): #{users[2].name}"

    # Usuários 3+ ficam ausentes (têm shift mas sem check-in)
    ausentes = users[3..]
    ausentes.each { |u| log "Ausente: #{u.name}" }

    panel_url = "https://backstage-staging-6j0k.onrender.com/teams/#{team.id}/panel"
    coord_email = users[0].email

    <<~TEXT
      ✅ Dados criados com sucesso!

      Evento:  #{event.name}
      Equipe:  #{team.name}

      Status dos membros:
        Presentes (2):    #{users[0].name}, #{users[1].name}
        Em atividade (1): #{users[2].name}
        Ausentes (#{ausentes.size}):     #{ausentes.map(&:name).join(", ")}

      👉 Acesse o painel:
      #{panel_url}

      🔑 Login como coordenador:
      #{coord_email}

      #{@log.map { |l| "  · #{l}" }.join("\n")}
    TEXT
  end

  private

  def log(msg)
    @log << msg
  end
end
