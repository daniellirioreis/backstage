class TeamsController < ApplicationController
  before_action :set_team, only: %i[show edit update destroy]

  def index
    authorize Team
    @teams = policy_scope(Team)
               .joins(:sector)
               .where(sectors: { event_id: current_event.id })
               .includes(:sector, :coordinator, users: [])
               .order("sectors.name, teams.name")
  end

  def show
    authorize @team
  end

  def new
    authorize Team
    @team         = Team.new(sector_id: params[:sector_id])
    @sectors      = Sector.where(event_id: current_event.id).order(:name)
    @all_users    = User.order(:name)
  end

  def create
    authorize Team
    @team = Team.new(team_params)
    if @team.save
      redirect_to teams_path, notice: t("notices.created", model: Team.model_name.human)
    else
      @sectors   = Sector.where(event_id: current_event.id).order(:name)
      @all_users = User.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @team
    @sectors   = Sector.where(event_id: current_event.id).order(:name)
    @all_users = User.order(:name)
  end

  def update
    authorize @team
    if @team.update(team_params)
      redirect_to teams_path, notice: t("notices.updated", model: Team.model_name.human)
    else
      @sectors   = Sector.where(event_id: current_event.id).order(:name)
      @all_users = User.order(:name)
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
    params.require(:team).permit(:name, :sector_id, :coordinator_id, user_ids: [])
  end
end
