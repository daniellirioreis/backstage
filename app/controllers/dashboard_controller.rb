class DashboardController < ApplicationController
  def index
    authorize :dashboard, :index?

    # Colaboradores → escala pessoal
    if current_user.role&.collaborator?
      redirect_to my_schedule_user_path(current_user) and return
    end

    # Coordenadores → painel da equipe
    if current_user.coordinator?
      membership = current_user.team_memberships.find_by(role: :coordinator)
      redirect_to(panel_team_path(membership.team_id)) and return if membership
      redirect_to(new_user_session_path, alert: "Você não está associado a nenhuma equipe como coordenador.") and return
    end

    company_ids = if current_user.admin?
      Company.pluck(:id)
    else
      current_user.company_users.pluck(:company_id)
    end

    event_ids = Event.where(company_id: company_ids).pluck(:id)

    @total_events   = event_ids.size
    @active_events  = Event.where(id: event_ids, status: :active).count
    @total_sectors  = Sector.where(event_id: event_ids).count
    @total_teams    = Team.joins(:sector).where(sectors: { event_id: event_ids }).count
    @total_members  = TeamMembership.joins(team: :sector)
                                    .where(sectors: { event_id: event_ids })
                                    .select(:user_id).distinct.count
    @total_vehicles = Vehicle.count
    @total_users    = company_ids.any? ? User.joins(:company_users)
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
    if @total_events > 0
      pairs = TeamMembership.joins(team: :sector)
                            .where(sectors: { event_id: event_ids })
                            .distinct
                            .pluck("sectors.event_id", :user_id)
      counts_per_event = pairs.group_by(&:first).transform_values(&:size)
      @avg_members_per_event = (counts_per_event.values.sum.to_f / @total_events).round(1)
    else
      @avg_members_per_event = 0
    end

    @events = Event.where(id: event_ids)
                   .includes(sectors: { teams: :team_memberships })
                   .order(start_date: :desc)

    # ── Custo por evento (turnos × taxa/hora da função) ───────────────────────
    all_shifts = Shift.joins(:sector)
                      .where(sectors: { event_id: event_ids })
                      .includes(:sector)

    memberships_map = TeamMembership.includes(:event_function)
                                    .where(team_id: all_shifts.map(&:team_id).compact.uniq)
                                    .each_with_object({}) { |m, h| h[[m.user_id, m.team_id]] = m }

    @event_costs         = Hash.new(0.0)
    @cost_by_sector_type = Hash.new(0.0)
    @cost_by_event_type  = Hash.new(0.0)
    @cost_matrix         = Hash.new { |h, k| h[k] = Hash.new(0.0) }
    @cost_by_month       = Hash.new(0.0)
    # { fn_name => { total: Float, event_ids: Set } }
    cost_by_function_raw = Hash.new { |h, k| h[k] = { total: 0.0, event_ids: Set.new } }

    # Mapa event_id → event_type para acumular custo por tipo de evento
    event_type_map = Event.where(id: event_ids).pluck(:id, :event_type).to_h

    all_shifts.each do |shift|
      next unless shift.team_id
      membership = memberships_map[[shift.user_id, shift.team_id]]
      rate       = membership&.event_function&.hourly_rate.to_f
      next unless rate > 0

      s = shift.start_time.hour * 60 + shift.start_time.min
      e = shift.end_time.hour   * 60 + shift.end_time.min
      hours_per_day = (e > s ? e - s : 1440 - s + e) / 60.0
      days = shift.end_date.present? ? (shift.end_date - shift.date).to_i + 1 : 1
      cost = hours_per_day * days * rate

      @event_costs[shift.sector.event_id] += cost
      @cost_by_sector_type[shift.sector.sector_type] += cost if shift.sector.sector_type.present?

      ev_type     = event_type_map[shift.sector.event_id]
      sector_type = shift.sector.sector_type

      @cost_by_event_type[ev_type] += cost if ev_type.present?
      @cost_matrix[ev_type][sector_type] += cost if ev_type.present? && sector_type.present?

      fn_name = membership&.event_function&.name
      if fn_name.present?
        cost_by_function_raw[fn_name][:total]     += cost
        cost_by_function_raw[fn_name][:event_ids] << shift.sector.event_id
      end

      @cost_by_month[shift.date.strftime("%Y-%m")] += cost
    end

    # Média de gasto por função por evento (total acumulado / nº eventos que usaram a função)
    @avg_cost_by_function = cost_by_function_raw
      .transform_values { |v| (v[:total] / v[:event_ids].size).round(2) }
      .sort_by { |_, avg| -avg }
      .to_h

    # Últimos 12 meses para o gráfico de evolução
    @last_12_months = (11.downto(0)).map { |n| (Date.today << n).strftime("%Y-%m") }

    # Top 5 colaboradores por número de turnos
    top_shifts = Shift.joins(:sector)
                      .where(sectors: { event_id: event_ids })
                      .group(:user_id)
                      .count
                      .sort_by { |_, c| -c }
                      .first(5)
    user_map = User.where(id: top_shifts.map(&:first)).index_by(&:id)
    @top_collaborators = top_shifts.map { |uid, count| [user_map[uid], count] }.compact

    @total_cost = @event_costs.values.sum

    # Contagem de eventos por tipo (para calcular média)
    @events_by_type = Event.where(id: event_ids)
                           .where.not(event_type: [nil, ""])
                           .group(:event_type)
                           .count

    # Contagem de setores por tipo (para calcular média)
    @sectors_by_type = Sector.where(event_id: event_ids)
                              .where.not(sector_type: nil)
                              .group(:sector_type)
                              .count

    # Referência de colaboradores por tipo de evento (média, min, máx)
    if event_ids.any?
      raw_collab = TeamMembership
                     .joins(team: { sector: :event })
                     .where(sectors: { event_id: event_ids })
                     .where.not("events.event_type" => [nil, ""])
                     .distinct
                     .pluck("events.event_type", "sectors.event_id", "team_memberships.user_id")

      # Conta colaboradores distintos por evento: { [event_type, event_id] => count }
      per_event = raw_collab.each_with_object(Hash.new(0)) do |(et, eid, _uid), h|
        h[[et, eid]] += 1
      end

      # Agrupa por event_type e calcula média, min, max
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

  end
end
