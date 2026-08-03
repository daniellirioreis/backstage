class DashboardController < ApplicationController
  def index
    authorize :dashboard, :index?

    # Colaboradores (perfil "colaborador" sem acesso ao dashboard) → escala pessoal
    if current_user.role&.name == "colaborador"
      redirect_to my_schedule_user_path(current_user) and return
    end

    # Coordenadores → painel da equipe onde são responsáveis (filtrado pelo evento corrente)
    if current_user.coordinator?
      team = if current_event
        Team.joins(:sector).find_by(coordinator_id: current_user.id, sectors: { event_id: current_event.id })
      else
        Team.find_by(coordinator_id: current_user.id)
      end
      redirect_to(panel_team_path(team)) and return if team
    end

    company_ids = if current_user.admin?
      Company.pluck(:id)
    else
      current_user.company_users.pluck(:company_id)
    end

    event_ids        = Event.where(company_id: company_ids).pluck(:id)
    closed_event_ids = Event.where(company_id: company_ids, status: :closed).pluck(:id)

    # ── Métricas simples ─────────────────────────────────────────────────────
    @total_events  = event_ids.size
    @active_events = Event.where(id: event_ids, status: :active).count
    @total_users   = company_ids.any? ? User.joins(:company_users)
                                             .where(company_users: { company_id: company_ids })
                                             .distinct.count : 0

    @events_by_status = Event.where(id: event_ids).group(:status).count

    # Próximos eventos (ativos ou rascunho, a partir de hoje)
    @upcoming_events = Event.where(id: event_ids, status: %w[active draft])
                            .where("start_date >= ?", Date.today)
                            .includes(:company)
                            .order(:start_date)
                            .limit(5)

    # Média de colaboradores por evento
    if @total_events > 0 && event_ids.any?
      pairs = TeamMembership.joins(team: :sector)
                            .where(sectors: { event_id: event_ids })
                            .distinct
                            .pluck("sectors.event_id", :user_id)
      counts_per_event       = pairs.group_by(&:first).transform_values(&:size)
      @avg_members_per_event = (counts_per_event.values.sum.to_f / @total_events).round(1)
    else
      @avg_members_per_event = 0
    end

    # ── Custo por evento via SQL (sem carregar todos os turnos em memória) ────
    # Substituiu: all_shifts (N objetos Shift) + memberships_map + loop Ruby
    # Agora: uma única query SQL com GROUP BY que agrega no banco
    @event_costs         = Hash.new(0.0)
    @cost_by_sector_type = Hash.new(0.0)
    @cost_by_event_type  = Hash.new(0.0)
    @cost_matrix         = Hash.new { |h, k| h[k] = Hash.new(0.0) }
    @cost_by_month       = Hash.new(0.0)
    cost_by_function_raw = Hash.new { |h, k| h[k] = { total: 0.0, event_ids: Set.new } }

    if closed_event_ids.any?
      cost_rows = ActiveRecord::Base.connection.execute(<<~SQL)
        SELECT
          sectors.event_id,
          sectors.sector_type,
          events.event_type,
          event_functions.name            AS function_name,
          TO_CHAR(shifts.date, 'YYYY-MM') AS year_month,
          SUM(
            CASE WHEN shifts.end_time > shifts.start_time
              THEN EXTRACT(EPOCH FROM (shifts.end_time - shifts.start_time)) / 3600.0
              ELSE 24.0 + EXTRACT(EPOCH FROM (shifts.end_time - shifts.start_time)) / 3600.0
            END
            * (COALESCE(shifts.end_date, shifts.date) - shifts.date + 1)
            * event_functions.hourly_rate
          ) AS total_cost
        FROM shifts
        INNER JOIN sectors ON sectors.id = shifts.sector_id
        INNER JOIN events  ON events.id  = sectors.event_id
        INNER JOIN team_memberships
          ON  team_memberships.user_id = shifts.user_id
          AND team_memberships.team_id = shifts.team_id
        INNER JOIN event_functions
          ON event_functions.id = team_memberships.event_function_id
        WHERE sectors.event_id IN (#{closed_event_ids.map(&:to_i).join(',')})
          AND shifts.team_id IS NOT NULL
          AND event_functions.hourly_rate > 0
        GROUP BY
          sectors.event_id,
          sectors.sector_type,
          events.event_type,
          event_functions.name,
          TO_CHAR(shifts.date, 'YYYY-MM')
      SQL

      cost_rows.each do |row|
        cost        = row["total_cost"].to_f
        event_id    = row["event_id"].to_i
        sector_type = row["sector_type"]
        event_type  = row["event_type"]
        fn_name     = row["function_name"]
        ym          = row["year_month"]

        @event_costs[event_id]                += cost
        @cost_by_sector_type[sector_type]     += cost if sector_type.present?
        @cost_by_event_type[event_type]       += cost if event_type.present?
        @cost_matrix[event_type][sector_type] += cost if event_type.present? && sector_type.present?
        @cost_by_month[ym]                    += cost if ym.present?

        if fn_name.present?
          cost_by_function_raw[fn_name][:total]     += cost
          cost_by_function_raw[fn_name][:event_ids] << event_id
        end
      end
    end

    # Média de gasto por função por evento
    @avg_cost_by_function = cost_by_function_raw
      .transform_values { |v| (v[:total] / v[:event_ids].size).round(2) }
      .sort_by { |_, avg| -avg }
      .to_h

    # Últimos 12 meses para o gráfico de evolução
    @last_12_months = (11.downto(0)).map { |n| (Date.today << n).strftime("%Y-%m") }
    @total_cost     = @event_costs.values.sum

    # Top 5 colaboradores por número de turnos
    if event_ids.any?
      top_shifts = Shift.joins(:sector)
                        .where(sectors: { event_id: event_ids })
                        .group(:user_id)
                        .count
                        .sort_by { |_, c| -c }
                        .first(5)
      user_map           = User.where(id: top_shifts.map(&:first)).index_by(&:id)
      @top_collaborators = top_shifts.map { |uid, count| [user_map[uid], count] }.compact
    else
      @top_collaborators = []
    end

    # Contagem de eventos por tipo (para calcular média) — apenas encerrados
    @events_by_type = Event.where(id: closed_event_ids)
                           .where.not(event_type: [nil, ""])
                           .group(:event_type)
                           .count

    # Contagem de setores por tipo (para calcular média) — apenas encerrados
    @sectors_by_type = Sector.where(event_id: closed_event_ids)
                              .where.not(sector_type: nil)
                              .group(:sector_type)
                              .count

    # Referência de colaboradores por tipo de evento (média, min, máx) — apenas encerrados
    if closed_event_ids.any?
      raw_collab = TeamMembership
                     .joins(team: { sector: :event })
                     .where(sectors: { event_id: closed_event_ids })
                     .where.not("events.event_type" => [nil, ""])
                     .distinct
                     .pluck("events.event_type", "sectors.event_id", "team_memberships.user_id")

      per_event = raw_collab.each_with_object(Hash.new(0)) do |(et, eid, _uid), h|
        h[[et, eid]] += 1
      end

      @collab_ref_by_event_type = per_event
        .group_by { |(et, _eid), _| et }
        .transform_values do |entries|
          counts = entries.map { |_, cnt| cnt }
          {
            avg:    (counts.sum.to_f / counts.size).round(1),
            min:    counts.min,
            max:    counts.max,
            events: counts.size
          }
        end
        .sort_by { |_, s| -s[:avg] }
        .to_h
    else
      @collab_ref_by_event_type = {}
    end

    # ── Visão Geral — dados extras ─────────────────────────────────────────────
    @total_sectors       = event_ids.any? ? Sector.where(event_id: event_ids).count : 0
    @closed_events_count = closed_event_ids.size

    # Taxa histórica de presença (média entre eventos encerrados)
    if closed_event_ids.any?
      members_by_ev  = TeamMembership.joins(team: :sector)
                                      .where(sectors: { event_id: closed_event_ids })
                                      .group("sectors.event_id")
                                      .distinct.count(:user_id)
      checkins_by_ev = Attendance.joins(:event)
                                  .where(event_id: closed_event_ids)
                                  .group(:event_id)
                                  .distinct.count(:user_id)
      rates = closed_event_ids.filter_map do |eid|
        m = members_by_ev[eid].to_i
        c = checkins_by_ev[eid].to_i
        m > 0 ? (c.to_f / m * 100) : nil
      end
      @historical_attendance_rate = rates.any? ? (rates.sum / rates.size).round : 0
    else
      @historical_attendance_rate = 0
    end

    # Evento em destaque (evento corrente da sessão)
    @featured_event = current_event
    if @featured_event
      feat_id = @featured_event.id
      @feat_sectors     = Sector.where(event_id: feat_id).count
      @feat_teams       = Team.joins(:sector).where(sectors: { event_id: feat_id }).count
      @feat_members     = TeamMembership.joins(team: :sector)
                                         .where(sectors: { event_id: feat_id })
                                         .distinct.count(:user_id)
      @feat_substitutes = TeamMembership.joins(team: :sector)
                                         .where(sectors: { event_id: feat_id }, substitute: true)
                                         .distinct.count(:user_id)
      @feat_checkins_today = Attendance.where(event_id: feat_id, checked_in_date: Date.today)
                                        .distinct.count(:user_id)
      @feat_credentials    = TeamMembership.joins(team: :sector)
                                            .where(sectors: { event_id: feat_id })
                                            .where.not(credential_code: [nil, ""])
                                            .distinct.count(:user_id)
      @feat_has_shifts     = Shift.joins(:sector).where(sectors: { event_id: feat_id }).exists?
      @feat_presence_pct   = @feat_members > 0 ? (@feat_checkins_today.to_f / @feat_members * 100).round : 0
    end

    # Alertas — eventos sem equipes ou sem escalas (ativos/rascunho)
    active_draft_ids = Event.where(company_id: company_ids, status: %w[active draft]).pluck(:id)
    if active_draft_ids.any?
      with_teams_ids  = Team.joins(:sector).where(sectors: { event_id: active_draft_ids })
                            .distinct.pluck("sectors.event_id").to_set
      with_shifts_ids = Shift.joins(:sector).where(sectors: { event_id: active_draft_ids })
                             .distinct.pluck("sectors.event_id").to_set
      without_teams_ids  = active_draft_ids.reject { |id| with_teams_ids.include?(id) }
      # Alerta de escala apenas para eventos que já têm equipe mas não têm escala
      without_shifts_ids = active_draft_ids.reject { |id| with_shifts_ids.include?(id) || !with_teams_ids.include?(id) }
      @events_without_teams  = Event.where(id: without_teams_ids).order(:start_date).limit(3)
      @events_without_shifts = Event.where(id: without_shifts_ids).order(:start_date).limit(3)
    else
      @events_without_teams  = Event.none
      @events_without_shifts = Event.none
    end

    # Check-outs faltando ontem (evento corrente)
    @missing_checkouts_count = if current_event
      Attendance.where(event_id: current_event.id,
                       checked_in_date: Date.today - 1,
                       checked_out_at: nil).count
    else
      0
    end

    # Calendário — todos os eventos num janela de 4 meses atrás até 8 meses à frente
    @calendar_events = Event.where(company_id: company_ids)
                            .where("end_date >= ? AND start_date <= ?",
                                   4.months.ago.to_date, 8.months.from_now.to_date)
                            .order(:start_date)
                            .includes(:responsible_user)
                            .select(:id, :name, :start_date, :end_date, :status, :responsible_user_id)

    # Próximos eventos com dados extras (membros, setores, equipes, escalas)
    if @upcoming_events.any?
      up_ids        = @upcoming_events.map(&:id)
      up_sectors    = Sector.where(event_id: up_ids).group(:event_id).count
      up_members    = TeamMembership.joins(team: :sector).where(sectors: { event_id: up_ids })
                                    .group("sectors.event_id").distinct.count(:user_id)
      up_has_teams  = Team.joins(:sector).where(sectors: { event_id: up_ids })
                          .distinct.pluck("sectors.event_id").to_set
      up_has_shifts = Shift.joins(:sector).where(sectors: { event_id: up_ids })
                           .distinct.pluck("sectors.event_id").to_set
      @upcoming_events_data = @upcoming_events.map do |ev|
        { event: ev,
          sectors:    up_sectors[ev.id].to_i,
          members:    up_members[ev.id].to_i,
          has_teams:  up_has_teams.include?(ev.id),
          has_shifts: up_has_shifts.include?(ev.id) }
      end
    else
      @upcoming_events_data = []
    end
  end
end
