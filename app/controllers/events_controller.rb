class EventsController < ApplicationController
  before_action :set_event, only: %i[show edit update destroy print transition revert]

  TRANSITIONS = { "draft" => "active", "active" => "closed" }.freeze

  def index
    authorize Event
    @events = policy_scope(Event).includes(:company, sectors: :teams).order(start_date: :desc)
  end

  def show
    authorize @event
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
      has_checkins = Attendance.where(event: @event).exists?
      if has_checkins
        redirect_to @event, alert: "Não é possível voltar para Rascunho: já existem check-ins registrados neste evento."
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
      :name, :code, :location, :start_date, :end_date, :status, :company_id,
      event_functions_attributes: [:id, :name, :hourly_rate, :_destroy],
      event_days_attributes: [:id, :date, :hours, :_destroy]
    )
  end
end
