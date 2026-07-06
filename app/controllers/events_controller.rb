class EventsController < ApplicationController
  before_action :set_event, only: %i[show edit update destroy print transition revert]

  TRANSITIONS = { "draft" => "active", "active" => "closed" }.freeze

  def index
    authorize Event

    valid_statuses  = %w[draft active closed]
    @status_filter  = params[:status].presence_in(valid_statuses)
    @status_counts  = policy_scope(Event).group(:status).count

    @q              = params[:q].to_s.strip
    @location_filter = params[:location].to_s.strip
    @date_from      = params[:date_from].presence
    @date_to        = params[:date_to].presence

    @events = policy_scope(Event)
                .includes(:company, sectors: { teams: :team_memberships })
                .then { |s| @status_filter ? s.where(status: @status_filter) : s }
                .then { |s| @q.present? ? s.where("events.name ILIKE ?", "%#{@q}%") : s }
                .then { |s| @location_filter.present? ? s.where("events.location ILIKE ?", "%#{@location_filter}%") : s }
                .then { |s| @date_from.present? ? s.where("events.end_date >= ?", @date_from) : s }
                .then { |s| @date_to.present? ? s.where("events.start_date <= ?", @date_to) : s }
                .order(start_date: :desc)

    # ── Stats do evento atual (hero card) ───────────────────────────────────
    if current_event
      @ev_sectors = Sector.where(event: current_event).count
      @ev_teams   = Team.joins(:sector).where(sectors: { event_id: current_event.id }).count
      @ev_members = TeamMembership.joins(team: :sector)
                                  .where(sectors: { event_id: current_event.id })
                                  .select(:user_id).distinct.count

      ev_team_ids    = Team.joins(:sector).where(sectors: { event_id: current_event.id }).pluck(:id)
      ev_shifts      = Shift.joins(:sector).where(sectors: { event_id: current_event.id })
      ev_memberships = TeamMembership.includes(:event_function)
                                     .where(team_id: ev_team_ids)
                                     .each_with_object({}) { |m, h| h[[m.user_id, m.team_id]] = m }
      @ev_cost = 0.0
      ev_shifts.each do |shift|
        next unless shift.team_id
        rate = ev_memberships[[shift.user_id, shift.team_id]]&.event_function&.hourly_rate.to_f
        next unless rate > 0
        s     = shift.start_time.hour * 60 + shift.start_time.min
        e     = shift.end_time.hour   * 60 + shift.end_time.min
        hours = (e > s ? e - s : 1440 - s + e) / 60.0
        days  = shift.end_date.present? ? (shift.end_date - shift.date).to_i + 1 : 1
        @ev_cost += hours * days * rate
      end

      if current_event.active?
        today = Date.today
        @ev_checkins_today  = Attendance.where(event: current_event, checked_in_date: today).count
        @ev_inside_now      = Attendance.where(event: current_event, checked_in_date: today, checked_out_at: nil).count
        @ev_checkouts_today = Attendance.where(event: current_event, checked_in_date: today).where.not(checked_out_at: nil).count
        @ev_expected_today  = Shift.joins(:sector)
                                   .where(sectors: { event_id: current_event.id })
                                   .where("shifts.date <= :d AND (shifts.end_date IS NULL OR shifts.end_date >= :d)", d: today)
                                   .select(:user_id).distinct.count
      elsif current_event.closed?
        @ev_total_checkins = Attendance.where(event: current_event).count
        @ev_present        = Attendance.where(event: current_event).select(:user_id).distinct.count
        @ev_paid           = Payment.where(event: current_event).sum(:amount)
      end
    end
  end

  def show
    authorize @event

    if current_event.nil?
      session[:current_event_id] = @event.id
      @current_event = @event
    end

    @sectors = @event.sectors.includes(sector_functions: :event_function,
                                       teams: [:users, :coordinator]).order(:name)
    all_team_ids = @sectors.flat_map { |s| s.teams.map(&:id) }
    @teams_with_shifts = Shift.where(team_id: all_team_ids).distinct.pluck(:team_id).to_set
    @event_functions = @event.event_functions.order(:name)
    @event_days_records = @event.event_days.ordered
    @total_event_hours  = @event.total_hours
    # fallback: se ainda não há event_days, usa dias × 8h
    if @total_event_hours.zero?
      @total_event_hours = ((@event.end_date - @event.start_date).to_i + 1) * 8.0
    end

    # ── Estimativa de planejamento (sector_functions × horas totais do evento) ─
    @plan_cost_by_function = Hash.new(0.0)
    @sectors.each do |sector|
      sector.sector_functions.each do |sf|
        ef = sf.event_function
        next unless ef.hourly_rate.to_f > 0
        @plan_cost_by_function[ef] += sf.quantity * ef.hourly_rate.to_f * @total_event_hours
      end
    end
    @plan_total_cost = @plan_cost_by_function.values.sum

    # ── Cruzamento: planejado vs atribuído por função ─────────────────────────
    headcount_planned = Hash.new(0)
    @sectors.each do |sector|
      sector.sector_functions.each do |sf|
        headcount_planned[sf.event_function] += sf.quantity
      end
    end

    if headcount_planned.any?
      headcount_assigned = TeamMembership
        .joins(team: :sector)
        .where(sectors: { event_id: @event.id })
        .where.not(event_function_id: nil)
        .group(:event_function_id)
        .count
      @headcount_by_function = headcount_planned
        .sort_by { |ef, _| ef.name }
        .each_with_object({}) do |(ef, planned), hash|
          hash[ef] = { planned: planned, assigned: headcount_assigned[ef.id] || 0 }
        end
    else
      @headcount_by_function = {}
    end

    # ── Custo realizado (baseado nas escalas reais) ───────────────────────────
    shifts = Shift.joins(:sector).where(sectors: { event_id: @event.id }).includes(:sector)
    memberships_map = TeamMembership.includes(:event_function)
                                    .where(team_id: all_team_ids)
                                    .each_with_object({}) { |m, h| h[[m.user_id, m.team_id]] = m }

    @cost_by_function = Hash.new(0.0)

    shifts.each do |shift|
      next unless shift.team_id
      membership = memberships_map[[shift.user_id, shift.team_id]]
      ef   = membership&.event_function
      rate = ef&.hourly_rate.to_f
      next unless rate > 0

      s = shift.start_time.hour * 60 + shift.start_time.min
      e = shift.end_time.hour   * 60 + shift.end_time.min
      hours = (e > s ? e - s : 1440 - s + e) / 60.0
      days  = shift.end_date.present? ? (shift.end_date - shift.date).to_i + 1 : 1
      @cost_by_function[ef] += hours * days * rate
    end

    @estimated_cost = @cost_by_function.values.sum

    # ── Total pago (payments registrados para este evento) ────────────────────
    @total_paid = Payment.where(event: @event).sum(:amount)

    # ── Economia: colaboradores escalados que não compareceram ────────────────
    if @event.closed?
      attended_user_ids = Attendance.where(event: @event).where.not(checked_out_at: nil).pluck(:user_id).uniq

      absent_cost = 0.0
      shifts.each do |shift|
        next if attended_user_ids.include?(shift.user_id)
        next unless shift.team_id
        membership = memberships_map[[shift.user_id, shift.team_id]]
        next unless membership&.event_function
        rate  = membership.event_function.hourly_rate.to_f
        next if rate.zero?
        s_min = shift.start_time.hour * 60 + shift.start_time.min
        e_min = shift.end_time.hour   * 60 + shift.end_time.min
        hours = e_min > s_min ? (e_min - s_min) / 60.0 : (1440 - s_min + e_min) / 60.0
        days  = shift.end_date.present? ? (shift.end_date - shift.date).to_i + 1 : 1
        absent_cost += hours * days * rate
      end
      @absent_cost = absent_cost
    end
  end

  def print
    authorize @event, :print?
    @sectors = @event.sectors.includes(teams: [:coordinator, { team_memberships: :user }, :users]).order(:name)
    respond_to do |format|
      format.html { render layout: "print" }
      format.pdf do
        render pdf: "evento-#{@event.name.parameterize}",
               template: "events/print",
               layout: "print",
               formats: [:html],
               page_size: "A4",
               orientation: "Portrait",
               margin: { top: 10, bottom: 10, left: 10, right: 10 },
               disposition: "attachment"
      end
    end
  end

  def event_type_stats
    authorize Event, :new?

    event_type = params[:event_type].presence
    unless event_type
      render json: { error: "event_type obrigatório" }, status: :unprocessable_entity and return
    end

    # Escopo de eventos visíveis pelo usuário
    company_ids = current_user.admin? ? Company.pluck(:id) : current_user.company_users.pluck(:company_id)
    event_ids   = Event.where(company_id: company_ids, event_type: event_type).pluck(:id)
    total_ev    = event_ids.size

    if total_ev == 0
      render json: { total_events: 0 } and return
    end

    # ── Colaboradores por evento (avg/min/max) ──────────────────────────────
    collab_pairs = TeamMembership
      .joins(team: :sector)
      .where(sectors: { event_id: event_ids })
      .distinct
      .pluck("sectors.event_id", "team_memberships.user_id")

    collab_per_event = collab_pairs.group_by(&:first).transform_values(&:size)
    counts = collab_per_event.values
    avg_collab = counts.any? ? (counts.sum.to_f / counts.size).round(1) : 0
    min_collab = counts.min || 0
    max_collab = counts.max || 0

    # ── Custo médio por evento ──────────────────────────────────────────────
    all_shifts = Shift.joins(:sector).where(sectors: { event_id: event_ids }).includes(:sector)
    team_ids   = all_shifts.map(&:team_id).compact.uniq
    memberships_map = TeamMembership.includes(:event_function)
      .where(team_id: team_ids)
      .each_with_object({}) { |m, h| h[[m.user_id, m.team_id]] = m }

    event_costs          = Hash.new(0.0)
    cost_by_fn_raw       = Hash.new { |h, k| h[k] = { total: 0.0, event_ids: Set.new } }
    collab_by_sector_raw = Hash.new { |h, k| h[k] = Hash.new { |hh, kk| hh[kk] = Set.new } }

    all_shifts.each do |shift|
      next unless shift.team_id
      membership  = memberships_map[[shift.user_id, shift.team_id]]
      rate        = membership&.event_function&.hourly_rate.to_f
      next unless rate > 0

      s    = shift.start_time.hour * 60 + shift.start_time.min
      e    = shift.end_time.hour   * 60 + shift.end_time.min
      hrs  = (e > s ? e - s : 1440 - s + e) / 60.0
      days = shift.end_date.present? ? (shift.end_date - shift.date).to_i + 1 : 1
      cost = hrs * days * rate

      event_costs[shift.sector.event_id] += cost

      fn_name = membership&.event_function&.name
      if fn_name.present?
        cost_by_fn_raw[fn_name][:total]     += cost
        cost_by_fn_raw[fn_name][:event_ids] << shift.sector.event_id
      end
    end

    total_cost = event_costs.values.sum
    avg_cost   = total_ev > 0 ? (total_cost / total_ev).round(2) : 0

    # Custo médio por função por evento (top 8)
    avg_cost_by_fn = cost_by_fn_raw
      .transform_values { |v| (v[:total] / v[:event_ids].size).round(2) }
      .sort_by { |_, v| -v }
      .first(8)
      .map { |name, avg| { label: name, avg_cost: avg } }

    # ── Setores mais usados (por sector_type, % dos eventos) ───────────────
    sector_rows = Sector
      .where(event_id: event_ids)
      .where.not(sector_type: nil)
      .group(:sector_type)
      .select("sector_type, COUNT(DISTINCT event_id) AS ev_count")

    sectors = sector_rows
      .sort_by { |r| -r.ev_count }
      .first(8)
      .map do |r|
        {
          sector_type: r.sector_type,
          label:       I18n.t("sector_types.#{r.sector_type}", default: r.sector_type.humanize),
          pct:         (r.ev_count.to_f / total_ev * 100).round
        }
      end

    # ── Colaboradores por sector_type (avg por evento) ─────────────────────
    cs_rows = TeamMembership
      .joins(team: :sector)
      .where(sectors: { event_id: event_ids })
      .where.not(sectors: { sector_type: nil })
      .distinct
      .pluck("sectors.sector_type", "sectors.event_id", "team_memberships.user_id")

    # { sector_type => { event_id => Set<user_id> } }
    cs_map = cs_rows.each_with_object(Hash.new { |h, k| h[k] = Hash.new { |hh, kk| hh[kk] = Set.new } }) do |(st, eid, uid), h|
      h[st][eid] << uid
    end

    collab_by_sector = cs_map
      .transform_values do |ev_map|
        counts_arr = ev_map.values.map(&:size)
        (counts_arr.sum.to_f / counts_arr.size).round(1)
      end
      .sort_by { |_, avg| -avg }
      .first(8)
      .map do |st, avg|
        {
          sector_type: st,
          label:       I18n.t("sector_types.#{st}", default: st.humanize),
          avg:         avg
        }
      end

    # ── Duração média (dias) ────────────────────────────────────────────────
    dur_rows  = Event.where(id: event_ids).pluck(:start_date, :end_date)
    avg_days  = dur_rows.any? ? (dur_rows.map { |s, e| (e - s).to_i + 1 }.sum.to_f / dur_rows.size).round(1) : nil

    render json: {
      total_events:     total_ev,
      avg_collaborators: avg_collab,
      min_collaborators: min_collab,
      max_collaborators: max_collab,
      avg_cost:          avg_cost,
      avg_days:          avg_days,
      sectors:           sectors,
      functions:         avg_cost_by_fn,
      collab_by_sector:  collab_by_sector
    }
  end

  def new
    authorize Event
    @event = Event.new
    @event.event_functions.build
  end

  def create
    authorize Event
    @event = Event.new(event_params)

    # Verifica limite do plano
    company = @event.company || current_user.companies.first
    if company && !company.can_add_event?
      redirect_to new_event_path,
        alert: "Limite de eventos atingido para o plano #{company.plan.name} (#{company.events_limit} eventos). Entre em contato para upgrade."
      return
    end

    if @event.save
      redirect_to edit_event_path(@event), notice: "Evento criado. Adicione as funções e valores abaixo."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @event
    @event.event_functions.build if @event.event_functions.empty?
  end

  def update
    authorize @event
    if @event.update(event_params)
      redirect_to events_path, notice: t("notices.updated", model: Event.model_name.human)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @event
    @event.destroy
    redirect_to events_path, notice: t("notices.destroyed", model: Event.model_name.human)
  end

  def transition
    authorize @event, :transition?
    next_status = TRANSITIONS[@event.status]
    unless next_status
      redirect_to @event, alert: "Este evento não pode mais mudar de status."
      return
    end
    if @event.update(status: next_status)
      label = next_status == "active" ? "ativado" : "encerrado"
      redirect_to @event, notice: "Evento #{label} com sucesso."
    else
      redirect_to @event, alert: "Não foi possível alterar o status."
    end
  end

  def revert
    authorize @event, :revert?

    case @event.status
    when "active"
      checkin_users = Attendance.where(event: @event).where.not(checked_in_at: nil).joins(:user).order("users.name").pluck("users.name").uniq
      if checkin_users.any?
        names = checkin_users.first(5).join(", ")
        suffix = checkin_users.size > 5 ? " e mais #{checkin_users.size - 5}." : "."
        redirect_to @event, alert: "Não é possível voltar para Rascunho: já existem check-ins registrados. Colaboradores: #{names}#{suffix}"
        return
      end
      @event.update!(status: "draft")
      redirect_to @event, notice: "Evento voltou para Rascunho."
    when "closed"
      @event.update!(status: "active")
      redirect_to @event, notice: "Evento reaberto como Ativo."
    else
      redirect_to @event, alert: "Este evento não pode ser revertido."
    end
  end

  private

  def set_event
    @event = Event.find(params[:id])
  end

  def event_params
    params.require(:event).permit(
      :name, :code, :location, :start_date, :end_date, :status, :event_type, :company_id,
      event_functions_attributes: [:id, :name, :hourly_rate, :_destroy],
      event_days_attributes: [:id, :date, :hours, :_destroy]
    )
  end
end
