class TeamsController < ApplicationController
  before_action :set_team, only: %i[show edit update destroy credentials]

  def search
    authorize Team, :index?
    q     = params[:q].to_s.strip
    scope = Team.joins(:sector)
                .where(sectors: { event_id: current_event&.id })
                .includes(:sector)
    scope = scope.where("teams.name ILIKE ? OR sectors.name ILIKE ?", "%#{q}%", "%#{q}%") if q.present?
    teams = scope.order("sectors.name, teams.name").limit(50)
    render json: teams.map { |t|
      { id: t.id, name: t.name, sector: t.sector.name, label: "#{t.sector.name} › #{t.name}" }
    }
  end

  def index
    authorize Team
    @sectors = Sector.where(event_id: current_event.id).order(:name)
    scope = policy_scope(Team)
              .joins(:sector)
              .where(sectors: { event_id: current_event.id })
              .includes(:sector, coordinator: { avatar_attachment: :blob }, team_memberships: { user: { avatar_attachment: :blob } })
              .order("sectors.name, teams.name")
    scope = scope.where(sector_id: params[:sector_id]) if params[:sector_id].present?
    @teams = scope
    @teams_with_shifts = Shift.where(team_id: @teams.map(&:id)).distinct.pluck(:team_id).to_set
  end

  def show
    authorize @team
    @memberships = TeamMembership.where(team_id: @team.id)
                                 .includes(user: [:role, { avatar_attachment: :blob }])
                                 .joins(:user)
                                 .order("users.name")
    @shifts_by_date = if Shift.column_names.include?("team_id")
      Shift.where(team_id: @team.id).includes(:user).order(:date, :start_time).group_by(&:date)
    else
      {}
    end
  end

  def schedule
    authorize @team, :show?

    if request.post?
      date        = params[:date].presence
      end_date    = params[:end_date].presence
      start_time  = params[:start_time].presence
      end_time    = params[:end_time].presence
      user_ids    = Array(params[:user_ids]).map(&:to_i).select { |id| id > 0 }

      if date.blank? || start_time.blank? || end_time.blank? || user_ids.empty?
        flash.now[:alert] = "Preencha data, horários e selecione ao menos um colaborador."
        @memberships = load_team_memberships
        render :schedule and return
      end

      created = 0
      user_ids.each do |uid|
        shift = Shift.new(
          user_id:    uid,
          sector_id:  @team.sector_id,
          date:       date,
          end_date:   end_date,
          start_time: start_time,
          end_time:   end_time,
        )
        created += 1 if shift.save
      end

      redirect_to team_path(@team), notice: "#{created} turno(s) criado(s) com sucesso."
    else
      @memberships = load_team_memberships
    end
  end

  def credentials
    authorize @team, :show?

    # Recarrega explicitamente todos os membros do banco
    event      = @team.sector.event
    coordinator = User.includes(avatar_attachment: :blob).find_by(id: @team.coordinator_id)
    memberships = TeamMembership.where(team_id: @team.id)
                                .includes(user: { avatar_attachment: :blob })
                                .order("users.name")

    members = []
    if coordinator
      members << {
        user: coordinator,
        is_coordinator: true,
        credential_code: @team.coordinator_full_credential_code
      }
    end

    memberships.each do |tm|
      next if tm.user_id == @team.coordinator_id
      members << {
        user: tm.user,
        is_coordinator: false,
        credential_code: tm.full_credential_code
      }
    end

    @badge_config = event.badge_config || BadgeConfig.defaults

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

  def load_team_memberships
    TeamMembership.where(team_id: @team.id)
                  .includes(user: [:role, { avatar_attachment: :blob }])
                  .joins(:user)
                  .order("users.name")
  end

  def team_params
    params.require(:team).permit(:name, :sector_id, :coordinator_id, :radio_channel, user_ids: [])
  end
end
