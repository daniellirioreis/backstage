class EventsController < ApplicationController
  before_action :set_event, only: %i[show edit update destroy print]

  def index
    authorize Event
    @events = policy_scope(Event).includes(:company, sectors: :teams).order(start_date: :desc)
  end

  def show
    authorize @event
    @sectors = @event.sectors.includes(teams: [:users, :coordinator]).order(:name)
    all_team_ids = @sectors.flat_map { |s| s.teams.map(&:id) }
    @teams_with_shifts = Shift.where(team_id: all_team_ids).distinct.pluck(:team_id).to_set
    @event_functions = @event.event_functions.order(:name)

    # ── Custo previsto ────────────────────────────────────────────────────────
    shifts = Shift.joins(:sector).where(sectors: { event_id: @event.id }).includes(:sector)
    memberships_map = TeamMembership.includes(:event_function)
                                    .where(team_id: all_team_ids)
                                    .each_with_object({}) { |m, h| h[[m.user_id, m.team_id]] = m }

    @estimated_cost = shifts.sum do |shift|
      next 0 unless shift.team_id
      rate = memberships_map[[shift.user_id, shift.team_id]]&.event_function&.hourly_rate.to_f
      next 0 unless rate > 0
      s = shift.start_time.hour * 60 + shift.start_time.min
      e = shift.end_time.hour   * 60 + shift.end_time.min
      hours = (e > s ? e - s : 1440 - s + e) / 60.0
      days  = shift.end_date.present? ? (shift.end_date - shift.date).to_i + 1 : 1
      hours * days * rate
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

  private

  def set_event
    @event = Event.find(params[:id])
  end

  def event_params
    params.require(:event).permit(
      :name, :code, :location, :start_date, :end_date, :status, :company_id,
      event_functions_attributes: [:id, :name, :hourly_rate, :_destroy]
    )
  end
end
