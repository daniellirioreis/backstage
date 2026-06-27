class EventsController < ApplicationController
  before_action :set_event, only: %i[show edit update destroy]

  def index
    authorize Event
    @events = policy_scope(Event).includes(sectors: :teams).order(start_date: :desc)
  end

  def show
    authorize @event
    @sectors = @event.sectors.includes(teams: :users).order(:name)
  end

  def new
    authorize Event
    @event = Event.new
  end

  def create
    authorize Event
    @event = Event.new(event_params)
    if @event.save
      redirect_to events_path, notice: t("notices.created", model: Event.model_name.human)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @event
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
    params.require(:event).permit(:name, :location, :start_date, :end_date, :status)
  end
end
