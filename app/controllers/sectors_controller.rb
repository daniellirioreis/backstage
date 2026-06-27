class SectorsController < ApplicationController
  before_action :set_sector, only: %i[show edit update destroy]

  def index
    authorize Sector
    @events = Event.order(:name)
    sectors = policy_scope(Sector).includes(:event, :teams).order("events.name, sectors.name").references(:event)
    sectors = sectors.where(event_id: params[:event_id]) if params[:event_id].present?
    @sectors = sectors
  end

  def show
    authorize @sector
    @teams  = @sector.teams.includes(:users)
    @shifts = @sector.shifts.includes(:user).order(:date, :start_time)
  end

  def new
    authorize Sector
    @sector = Sector.new(event_id: params[:event_id])
    @events = Event.order(:name)
  end

  def create
    authorize Sector
    @sector = Sector.new(sector_params)
    if @sector.save
      redirect_to sectors_path, notice: t("notices.created", model: Sector.model_name.human)
    else
      @events = Event.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @sector
    @events = Event.order(:name)
  end

  def update
    authorize @sector
    if @sector.update(sector_params)
      redirect_to sectors_path, notice: t("notices.updated", model: Sector.model_name.human)
    else
      @events = Event.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @sector
    @sector.destroy
    redirect_to sectors_path, notice: t("notices.destroyed", model: Sector.model_name.human)
  end

  private

  def set_sector
    @sector = Sector.find(params[:id])
  end

  def sector_params
    params.require(:sector).permit(:name, :event_id)
  end
end
