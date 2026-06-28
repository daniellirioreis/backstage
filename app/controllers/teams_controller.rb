class TeamsController < ApplicationController
  before_action :set_team, only: %i[show edit update destroy credentials]

  def index
    authorize Team
    @teams = policy_scope(Team)
               .joins(:sector)
               .where(sectors: { event_id: current_event.id })
               .includes(:sector, coordinator: { avatar_attachment: :blob }, users: { avatar_attachment: :blob })
               .order("sectors.name, teams.name")
  end

  def show
    authorize @team
  end

  def credentials
    authorize @team, :show?

    # Recarrega explicitamente todos os membros do banco
    coordinator = User.includes(avatar_attachment: :blob).find_by(id: @team.coordinator_id)
    collaborators = User.includes(avatar_attachment: :blob)
                        .joins(:team_memberships)
                        .where(team_memberships: { team_id: @team.id })
                        .order(:name)

    members = []
    members << { user: coordinator, is_coordinator: true } if coordinator

    collaborators.each do |u|
      next if u.id == @team.coordinator_id
      members << { user: u, is_coordinator: false }
    end

    @badge_config = @team.sector.event.badge_config || BadgeConfig.defaults

    @members = members.map do |m|
      user = m[:user]
      avatar_b64 = if user.avatar.attached?
        blob = user.avatar.blob
        "data:#{blob.content_type};base64,#{Base64.strict_encode64(blob.download)}"
      end
      m.merge(avatar_base64: avatar_b64)
    end

    respond_to do |format|
      format.html { render layout: "credentials_preview" }
      format.pdf do
        render pdf: "credenciais-#{@team.name.parameterize}",
               template: "teams/credentials_pdf",
               layout: "credential_pdf",
               formats: [:html],
               page_size: "A4",
               orientation: "Portrait",
               margin: { top: 20, bottom: 20, left: 20, right: 20 },
               disposition: "attachment"
      end
    end
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
