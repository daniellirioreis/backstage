class TeamsController < ApplicationController
  before_action :set_team, only: %i[show edit update destroy]

  def index
    authorize Team
    @teams = policy_scope(Team).includes(:event).order("events.name, teams.name").references(:event)
  end

  def show
    authorize @team
    @sectors = @team.sectors
  end

  def new
    authorize Team
    @team = Team.new(event_id: params[:event_id])
  end

  def create
    authorize Team
    @team = Team.new(team_params)
    if @team.save
      redirect_to teams_path, notice: t("notices.created", model: Team.model_name.human)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @team
  end

  def update
    authorize @team
    if @team.update(team_params)
      redirect_to teams_path, notice: t("notices.updated", model: Team.model_name.human)
    else
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
    @team = Team.find(params[:id])
  end

  def team_params
    params.require(:team).permit(:name, :event_id)
  end
end
