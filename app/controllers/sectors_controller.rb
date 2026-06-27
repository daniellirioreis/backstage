class SectorsController < ApplicationController
  before_action :set_sector, only: %i[show edit update destroy]

  def index
    authorize Sector
    @sectors = policy_scope(Sector).includes(team: :event).order("events.name, teams.name, sectors.name").references(team: :event)
  end

  def show
    authorize @sector
    @shifts = @sector.shifts.includes(:user).order(:date, :start_time)
  end

  def new
    authorize Sector
    @sector = Sector.new(team_id: params[:team_id])
  end

  def create
    authorize Sector
    @sector = Sector.new(sector_params)
    if @sector.save
      redirect_to sectors_path, notice: t("notices.created", model: Sector.model_name.human)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @sector
  end

  def update
    authorize @sector
    if @sector.update(sector_params)
      redirect_to sectors_path, notice: t("notices.updated", model: Sector.model_name.human)
    else
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
    params.require(:sector).permit(:name, :team_id)
  end
end
