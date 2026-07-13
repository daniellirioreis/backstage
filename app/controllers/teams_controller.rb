class TeamsController < ApplicationController
  before_action :set_team, only: %i[show edit update destroy credentials import_members set_function schedule quick_add_member panel]

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
    return redirect_to(select_event_path, alert: "Selecione um evento para continuar.") unless current_event
    authorize Team
    @sectors = Sector.where(event_id: current_event.id).order(:name)
    scope = policy_scope(Team)
              .joins(:sector)
              .where(sectors: { event_id: current_event.id })
              .includes(:sector, coordinator: { avatar_attachment: :blob }, team_memberships: [:event_function, { user: { avatar_attachment: :blob } }])
              .order("sectors.name, teams.name")
    scope = scope.where(sector_id: params[:sector_id]) if params[:sector_id].present?
    scope = scope.where(coordinator_id: nil) if params[:without_coordinator] == "1"
    if params[:without_shifts] == "1"
      teams_with_shifts_ids = Shift.joins(sector: :event)
                                   .where(sectors: { event_id: current_event.id })
                                   .distinct.pluck(:team_id)
      scope = scope.where.not(id: teams_with_shifts_ids)
    end
    @teams = scope
    @teams_with_shifts = Shift.where(team_id: @teams.map(&:id)).distinct.pluck(:team_id).to_set
    @sector_function_data  = load_sector_function_data
    @event_functions_map   = current_event.event_functions.index_by { |ef| ef.id.to_s }
  end

  def coordinator
    authorize :team, :coordinator?
    return redirect_to(select_event_path, alert: "Selecione um evento para continuar.") unless current_event

    @teams = Team.where(coordinator_id: current_user.id)
                 .joins(:sector)
                 .where(sectors: { event_id: current_event.id })
                 .includes(:sector, team_memberships: [:event_function, { user: { avatar_attachment: :blob } }])
                 .order("sectors.name, teams.name")

    @teams_data = @teams.map do |team|
      all_memberships = team.team_memberships.sort_by { |tm| [tm.role == "coordinator" ? 0 : 1, tm.user.name] }
      all_user_ids    = all_memberships.map(&:user_id)

      # Busca turnos que cobrem hoje (incluindo multi-dia: date <= hoje <= end_date)
      shifts = Shift.where(user_id: all_user_ids, sector_id: team.sector_id)
                    .where("date <= ? AND (end_date IS NULL OR end_date >= ?)", Date.today, Date.today)
                    .index_by(&:user_id)

      # Presenças de TODOS os membros (com ou sem escala)
      today_att = Attendance.where(user_id: all_user_ids, event_id: current_event.id, checked_in_date: Date.today).index_by(&:user_id)
      all_att   = Attendance.where(user_id: all_user_ids, event_id: current_event.id)
                            .order(checked_in_at: :desc).group_by(&:user_id).transform_values(&:first)

      # Para membros sem escala hoje mas com check-in: buscar o próximo turno deles
      unscheduled_user_ids = all_user_ids - shifts.keys
      next_shifts = Shift.where(user_id: unscheduled_user_ids, sector_id: team.sector_id)
                         .where("date >= ?", Date.today)
                         .order(:date)
                         .group_by(&:user_id)
                         .transform_values(&:first)

      # Lista principal: tem escala hoje OU fez check-in hoje (mesmo sem escala)
      memberships = all_memberships.select { |tm| shifts.key?(tm.user_id) || today_att.key?(tm.user_id) }

      # "Sem escala" = sem escala E sem check-in (não aparecem na lista principal)
      memberships_no_shift = all_memberships.reject { |tm| shifts.key?(tm.user_id) || today_att.key?(tm.user_id) }

      member_status = memberships.each_with_object({}) do |tm, h|
        att = today_att[tm.user_id]
        h[tm.user_id] = att.nil? ? :absent : att.checked_out_at.nil? ? :active : :present
      end

      # Stats baseados nos membros com escala (expectativa do dia)
      scheduled_ids       = shifts.keys
      scheduled_att       = today_att.select { |uid, _| scheduled_ids.include?(uid) }
      unscheduled_checkin = today_att.reject { |uid, _| scheduled_ids.include?(uid) }

      {
        team:                  team,
        event:                 current_event,
        memberships:           memberships,
        memberships_no_shift:  memberships_no_shift,
        all_attendances:       all_att,
        shifts_today:          shifts,
        next_shifts:           next_shifts,
        member_status:         member_status,
        total:                 scheduled_ids.size,
        total_members:         all_memberships.size,
        present:               scheduled_att.values.count { |a| a.checked_out_at.present? },
        active:                scheduled_att.values.count { |a| a.checked_out_at.nil? },
        absent:                scheduled_ids.size - scheduled_att.size,
        unscheduled_checkin:   unscheduled_checkin.size
      }
    end
  end

  def panel
    authorize @team, :panel?

    @event = @team.sector.event

    all_memberships = TeamMembership
      .where(team_id: @team.id)
      .includes(:event_function, user: { avatar_attachment: :blob })
      .joins(:user)
      .order(role: :desc, "users.name": :asc)

    user_ids = all_memberships.map(&:user_id)

    # Presenças de hoje neste evento
    today_attendances = Attendance
      .where(user_id: user_ids, event_id: @event.id, checked_in_date: Date.today)
      .index_by(&:user_id)

    # Todas as presenças do evento (para histórico)
    @all_attendances = Attendance
      .where(user_id: user_ids, event_id: @event.id)
      .order(checked_in_at: :desc)
      .group_by(&:user_id)
      .transform_values(&:first)

    # Turnos de hoje (incluindo multi-dia: date <= hoje <= end_date)
    @shifts_today = Shift
      .where(user_id: user_ids, sector_id: @team.sector_id)
      .where("date <= ? AND (end_date IS NULL OR end_date >= ?)", Date.today, Date.today)
      .index_by(&:user_id)

    # Próximas escalas para membros sem turno hoje
    scheduled_ids        = @shifts_today.keys
    unscheduled_user_ids = user_ids - scheduled_ids
    @next_shifts = Shift
      .where(user_id: unscheduled_user_ids, sector_id: @team.sector_id)
      .where("date >= ?", Date.today)
      .order(:date)
      .group_by(&:user_id)
      .transform_values(&:first)

    # Lista principal: tem escala hoje OU fez check-in hoje (sem escala)
    @memberships         = all_memberships.select { |tm| @shifts_today.key?(tm.user_id) || today_attendances.key?(tm.user_id) }
    @memberships_no_shift = all_memberships.reject { |tm| @shifts_today.key?(tm.user_id) || today_attendances.key?(tm.user_id) }

    @total_members = all_memberships.size

    # Stats baseados nos membros com escala (expectativa do dia)
    scheduled_att        = today_attendances.select { |uid, _| scheduled_ids.include?(uid) }
    unscheduled_checkin  = today_attendances.reject { |uid, _| scheduled_ids.include?(uid) }

    @total_scheduled     = scheduled_ids.size
    @present_today       = scheduled_att.values.count { |a| a.checked_out_at.present? }
    @active_now          = scheduled_att.values.count { |a| a.checked_out_at.nil? }
    @absent_today        = scheduled_ids.size - scheduled_att.size
    @unscheduled_checkin = unscheduled_checkin.size

    # Para a view saber o status de cada membro
    @member_status = all_memberships.each_with_object({}) do |tm, h|
      att = today_attendances[tm.user_id]
      h[tm.user_id] = if att.nil?
        :absent
      elsif att.checked_out_at.nil?
        :active
      else
        :present
      end
    end
  end

  def show
    authorize @team
    @memberships = TeamMembership.where(team_id: @team.id)
                                 .includes(:event_function, user: [:role, { avatar_attachment: :blob }])
                                 .joins(:user)
                                 .order("users.name")
    @event_functions = @team.sector.event.event_functions.order(:name)
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

      if params[:modal] == "1"
        render html: "<script>window.parent.closeShiftModal(); window.parent.location.reload();</script>".html_safe, layout: false
      else
        redirect_to team_path(@team), notice: "#{created} turno(s) criado(s) com sucesso."
      end
    else
      @memberships = load_team_memberships
    end
  end

  def credentials
    authorize @team, :credentials?

    event = @team.sector.event
    memberships = TeamMembership.where(team_id: @team.id)
                                .includes(:event_function, user: { avatar_attachment: :blob })
                                .joins(:user)
                                .order(role: :desc).order("users.name")

    members = memberships.map do |tm|
      {
        user:            tm.user,
        is_coordinator:  tm.coordinator?,
        credential_code: tm.full_credential_code,
        function_name:   tm.event_function&.name
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
    @all_users    = company_users_scope.order(:name)
    @event_functions = current_event.event_functions.order(:name)
    @sector_function_data  = load_sector_function_data
    @team_saved_fn_counts  = {}
    @team.team_memberships.build
  end

  def create
    authorize Team
    @team = Team.new(team_params)
    if @team.save
      redirect_to teams_path, notice: t("notices.created", model: Team.model_name.human)
    else
      @sectors              = Sector.where(event_id: current_event.id).order(:name)
      @all_users            = User.order(:name)
      @event_functions      = current_event.event_functions.order(:name)
      @sector_function_data = load_sector_function_data
      @team_saved_fn_counts = {}
      render :new, status: :unprocessable_entity
    end
  end

  # AJAX: retorna JSON com equipes de um evento
  def import_source_teams
    authorize Team, :index?
    event_id = params[:event_id]
    teams = Team.joins(:sector)
                .where(sectors: { event_id: event_id })
                .includes(:sector)
                .order("sectors.name, teams.name")
    render json: teams.map { |t| { id: t.id, label: "#{t.sector.name} › #{t.name}" } }
  end

  # AJAX: retorna JSON com membros de uma equipe
  def import_source_members
    authorize Team, :index?
    source_team = Team.includes(team_memberships: { user: { avatar_attachment: :blob } })
                      .find(params[:source_team_id])
    target_team = Team.find(params[:target_team_id])
    existing_ids = target_team.team_memberships.pluck(:user_id)

    members = source_team.team_memberships.includes(user: { avatar_attachment: :blob }).joins(:user).order("users.name")
    render json: members.map { |tm|
      u = tm.user
      {
        id:          u.id,
        name:        u.name,
        phone:       u.phone,
        initials:    u.name.split.map(&:first).first(2).join.upcase,
        avatar_url:  u.avatar.attached? ? url_for(u.avatar) : nil,
        coordinator: u.id == source_team.coordinator_id,
        already:     existing_ids.include?(u.id)
      }
    }
  end

  # PATCH: atribui função a um membro da equipe
  def set_function
    authorize @team, :edit?
    membership = @team.team_memberships.find(params[:membership_id])
    membership.update!(event_function_id: params[:event_function_id].presence)
    redirect_to edit_team_path(@team), notice: "Função atualizada."
  end

  # GET AJAX: usuários da empresa disponíveis para adicionar à equipe
  def search_available
    authorize Team, :index?
    q            = params[:q].to_s.strip
    team         = Team.find(params[:team_id])
    existing_ids = team.team_memberships.pluck(:user_id)
    company      = current_event&.company

    scope = company ? company_users_scope : User.all
    scope = scope.where.not(id: existing_ids)
    scope = scope.where("users.name ILIKE ? OR users.phone ILIKE ?", "%#{q}%", "%#{q}%") if q.present?

    users = scope.order("users.name").limit(10)
    render json: users.map { |u|
      { id: u.id, name: u.name, phone: u.phone,
        initials: u.name.split.map(&:first).first(2).join.upcase }
    }
  end

  # POST: adiciona substituto (existente ou novo) à equipe
  def quick_add_member
    authorize @team, :manage_members?

    event_function_id = params[:event_function_id].presence

    if params[:user_id].present?
      user = User.find(params[:user_id])
    else
      # Cria usuário simplificado (substituto sem conta)
      collaborator_role = Role.find_by(collaborator: true) || Role.first
      temp_email = "sub.#{SecureRandom.hex(5)}@substituto.backstage"

      user = User.new(
        name:                      params[:name].to_s.strip,
        phone:                     params[:phone].to_s.strip.presence,
        email:                     temp_email,
        password:                  SecureRandom.hex(16),
        role:                      collaborator_role,
        skip_required_validations: true
      )

      unless user.save
        return render json: { status: :error, errors: user.errors.full_messages }, status: :unprocessable_entity
      end

      # Vincula à empresa do evento
      company = @team.sector.event.company
      CompanyUser.find_or_create_by!(user: user, company: company) if company
    end

    if @team.team_memberships.exists?(user_id: user.id)
      return render json: { status: :error, errors: ["#{user.name} já está na equipe"] }, status: :unprocessable_entity
    end

    membership = @team.team_memberships.create!(
      user_id:           user.id,
      event_function_id: event_function_id,
      substitute:        true
    )

    render json: {
      status:       :ok,
      message:      "#{user.name} adicionado(a) à equipe com sucesso.",
      membership: {
        user_id:         user.id,
        name:            user.name,
        phone:           user.phone,
        initials:        user.name.split.map(&:first).first(2).join.upcase,
        credential_code: membership.full_credential_code,
        function_name:   membership.event_function&.name || "—",
        is_new_user:     params[:user_id].blank?
      }
    }
  end

  # POST: importa membros selecionados
  def import_members
    authorize @team, :manage_members?
    user_ids = Array(params[:user_ids]).map(&:to_i).select { |id| id > 0 }
    imported = 0
    user_ids.each do |uid|
      next if @team.team_memberships.exists?(user_id: uid)
      @team.team_memberships.create(user_id: uid)
      imported += 1
    end
    redirect_to teams_path, notice: "#{imported} colaborador(es) importado(s) para #{@team.name}."
  end

  def edit
    authorize @team
    @sectors         = Sector.where(event_id: current_event.id).order(:name)
    @all_users       = User.order(:name)
    @memberships     = @team.team_memberships.includes(:event_function, user: :role).joins(:user).order("users.name")
    @event_functions = @team.sector.event.event_functions.order(:name)
    @sector_function_data  = load_sector_function_data
    @team_saved_fn_counts  = team_fn_counts(@team)
  end

  def update
    authorize @team
    if @team.update(team_params)
      redirect_to teams_path, notice: t("notices.updated", model: Team.model_name.human)
    else
      @sectors              = Sector.where(event_id: current_event.id).order(:name)
      @all_users            = User.order(:name)
      @memberships          = @team.team_memberships.includes(:event_function, user: :role).joins(:user).order("users.name")
      @event_functions      = @team.sector.event.event_functions.order(:name)
      @sector_function_data = load_sector_function_data
      @team_saved_fn_counts = team_fn_counts(@team)
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

  # Contagem de funções já salvas desta equipe: { "fn_id" => count }
  def team_fn_counts(team)
    team.team_memberships
        .where.not(event_function_id: nil)
        .group(:event_function_id)
        .count
        .transform_keys(&:to_s)
  end

  def load_sector_function_data
    # Quantidades planejadas: { sector_id => { fn_id => qty } }
    planned = {}
    Sector.where(event_id: current_event.id)
          .includes(:sector_functions)
          .each do |sector|
            next if sector.sector_functions.empty?
            sid = sector.id.to_s
            sector.sector_functions.each do |sf|
              planned[sid] ||= {}
              planned[sid][sf.event_function_id.to_s] = sf.quantity
            end
          end

    # Contagem já atribuída: { sector_id => { fn_id => count } }
    assigned = {}
    sector_ids = Sector.where(event_id: current_event.id).select(:id)
    TeamMembership
      .joins(team: :sector)
      .where(teams: { sector_id: sector_ids })
      .where.not(event_function_id: nil)
      .group("sectors.id", "team_memberships.event_function_id")
      .count
      .each do |(sector_id, fn_id), count|
        assigned[sector_id.to_s] ||= {}
        assigned[sector_id.to_s][fn_id.to_s] = count
      end

    { planned: planned, assigned: assigned }
  end

  def load_team_memberships
    TeamMembership.where(team_id: @team.id)
                  .includes(user: [:role, { avatar_attachment: :blob }])
                  .joins(:user)
                  .order("users.name")
  end

  def team_params
    params.require(:team).permit(
      :name, :sector_id, :coordinator_id, :radio_channel,
      team_memberships_attributes: [:id, :user_id, :event_function_id, :_destroy]
    )
  end
end
