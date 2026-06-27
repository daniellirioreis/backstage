class TeamsController < ApplicationController
  before_action :set_team, only: %i[show edit update destroy]

  def index
    authorize Team
    @events = Event.order(:name)
    teams = policy_scope(Team).includes(sector: :event, users: []).order("events.name, sectors.name, teams.name").references(sector: :event)
    teams = teams.joins(:sector).where(sectors: { event_id: params[:event_id] }) if params[:event_id].present?
    @events_with_teams = teams.group_by { |t| t.sector.event }
  end

  def show
    authorize @team
  end

  def new
    authorize Team
    @team    = Team.new(sector_id: params[:sector_id])
    @sectors = Sector.includes(:event).order("events.name, sectors.name").references(:event)
  end

  def create
    authorize Team
    @team = Team.new(team_params)
    if @team.save
      redirect_to teams_path, notice: t("notices.created", model: Team.model_name.human)
    else
      @sectors = Sector.includes(:event).order("events.name, sectors.name").references(:event)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @team
    @sectors = Sector.includes(:event).order("events.name, sectors.name").references(:event)
  end

  def update
    authorize @team
    if @team.update(team_params)
      redirect_to teams_path, notice: t("notices.updated", model: Team.model_name.human)
    else
      @sectors = Sector.includes(:event).order("events.name, sectors.name").references(:event)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @team
    @team.destroy
    redirect_to teams_path, notice: t("notices.destroyed", model: Team.model_name.human)
  end

  private

  def set_team
    @team = Team.includes(:users, sector: :event).find(params[:id])
  end

  def team_params
    params.require(:team).permit(:name, :sector_id, user_ids: [])
  end
end
