class ShiftsController < ApplicationController
  before_action :set_shift, only: %i[show edit update destroy]

  def index
    authorize Shift
    shifts = policy_scope(Shift)
               .joins(:sector)
               .where(sectors: { event_id: current_event.id })
               .includes(:user, { team: [:coordinator, :sector] }, :sector)
               .order(:date, :start_time)
    @shifts_by_team = shifts.group_by(&:team)

    team_ids = @shifts_by_team.keys.compact.map(&:id)
    memberships = TeamMembership.where(team_id: team_ids)
    @credential_map = memberships.each_with_object({}) do |tm, h|
      h[[tm.team_id, tm.user_id]] = tm.full_credential_code
    end
    @shifts_by_team.keys.compact.each do |team|
      if team.coordinator_id.present? && team.coordinator_full_credential_code.present?
        @credential_map[[team.id, team.coordinator_id]] ||= team.coordinator_full_credential_code
      end
    end
  end

  def timeline
    authorize Shift, :timeline?
    @event = current_event

    # Data selecionada (default: primeiro dia do evento ou hoje)
    @date = params[:date].present? ? Date.parse(params[:date]) : (@event&.start_date || Date.today)

    # Turnos do dia (inclui multi-dia: date <= @date <= end_date)
    shifts = policy_scope(Shift)
               .includes(:user, { team: [:coordinator, :sector] })
               .where("date <= ? AND (end_date IS NULL OR end_date >= ?)", @date, @date)
               .order(:start_time)

    # Agrupa por setor → equipe → lista de turnos
    @sectors_data = shifts.group_by { |s| s.team&.sector }.reject { |s, _| s.nil? }.sort_by { |s, _| s.name }
    @sectors_data = @sectors_data.map do |sector, sector_shifts|
      teams_data = sector_shifts.group_by(&:team).sort_by { |t, _| t.name }
      [sector, teams_data]
    end

    # Datas disponíveis para o seletor
    @available_dates = if @event
      (@event.start_date..@event.end_date).to_a
    else
      Shift.distinct.pluck(:date).sort
    end
  end

  def print
    authorize Shift, :print?
    @event = current_event
    shifts = policy_scope(Shift)
               .joins(:sector)
               .where(sectors: { event_id: @event.id })
               .includes(:user, { team: [:coordinator, :sector] }, :sector)
               .order(:date, :start_time)
    @shifts_by_team = shifts.group_by(&:team).reject { |team, _| team.nil? }

    team_ids = @shifts_by_team.keys.map(&:id)
    memberships = TeamMembership.where(team_id: team_ids)
    @credential_map = memberships.each_with_object({}) do |tm, h|
      h[[tm.team_id, tm.user_id]] = tm.full_credential_code
    end
    @shifts_by_team.keys.each do |team|
      if team.coordinator_id.present? && team.coordinator_full_credential_code.present?
        @credential_map[[team.id, team.coordinator_id]] ||= team.coordinator_full_credential_code
      end
    end
    @print_back_path = shifts_path
    @print_title = "Escalas · #{@event&.name}"
    render layout: "print"
  end

  def show
    authorize @shift
  end

  def new
    authorize Shift
    @shift      = Shift.new
    @event      = current_event
    @teams = Team.joins(:sector)
                 .where(sectors: { event_id: @event&.id })
                 .includes(:sector)
                 .order("sectors.name, teams.name")

    if params[:team_id].present?
      @selected_team    = Team.includes(sector: :event).find_by(id: params[:team_id])
      @team_has_shifts  = Shift.where(team_id: @selected_team.id).exists?
      @team_members     = TeamMembership.where(team_id: @selected_team.id)
                                        .includes(user: { avatar_attachment: :blob })
                                        .joins(:user)
                                        .order("users.name")
    end
  end

  def create
    authorize Shift
    team = Team.find_by(id: params[:team_id])

    unless team
      redirect_to new_shift_path, alert: "Selecione uma equipe." and return
    end

    members  = params[:members].to_unsafe_h rescue {}
    date     = params[:date]
    end_date = params[:end_date].presence

    created  = 0
    failures = []   # [{ name:, messages: [] }]
    skipped  = []   # nomes sem horário

    members.each do |user_id, data|
      next unless data[:selected] == "1"

      if data[:start_time].blank? || data[:end_time].blank?
        skipped << User.find_by(id: user_id)&.name
        next
      end

      shift = Shift.new(
        user_id:    user_id,
        sector_id:  team.sector_id,
        team_id:    team.id,
        date:       date,
        end_date:   end_date,
        start_time: data[:start_time],
        end_time:   data[:end_time],
      )

      if shift.save
        created += 1
      else
        failures << { name: User.find_by(id: user_id)&.name, messages: shift.errors.full_messages }
      end
    end

    if failures.any?
      # Re-renderiza o formulário mantendo os dados preenchidos
      @event           = current_event
      @teams           = Team.joins(:sector).where(sectors: { event_id: @event&.id }).includes(:sector).order("sectors.name, teams.name")
      @selected_team   = team
      @team_has_shifts = created > 0  # alguns já foram salvos
      @team_members    = TeamMembership.where(team_id: team.id)
                                       .includes(user: { avatar_attachment: :blob })
                                       .joins(:user)
                                       .order("users.name")
      @submitted_members = members     # preserva horários digitados
      @shift_errors      = failures    # erros por colaborador
      @shift_created     = created
      @shift_skipped     = skipped
      render :new, status: :unprocessable_entity
    elsif created == 0
      redirect_to new_shift_path(date: date, end_date: end_date, team_id: team.id),
        alert: "Nenhum turno foi salvo.#{skipped.any? ? " Sem horário: #{skipped.join(', ')}." : ''}"
    else
      msg = "#{created} turno(s) criado(s) com sucesso."
      msg += " Sem horário (ignorados): #{skipped.join(', ')}." if skipped.any?
      redirect_to shifts_path, notice: msg
    end
  end

  def edit
    authorize @shift
    load_form_data
  end

  def update
    authorize @shift
    if @shift.update(shift_params)
      redirect_back_or_to shifts_path, notice: t("notices.updated", model: Shift.model_name.human)
    else
      load_form_data
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @shift
    @shift.destroy
    redirect_to shifts_path, notice: t("notices.destroyed", model: Shift.model_name.human)
  end

  private

  def set_shift
    @shift = Shift.find(params[:id])
  end

  def load_form_data
    event_id    = current_event&.id
    @teams      = Team.joins(:sector).where(sectors: { event_id: event_id }).includes(:sector).order("sectors.name, teams.name")
    @sectors    = Sector.where(event_id: event_id).order(:name)
    @all_users  = User.order(:name)
  end

  def shift_params
    params.require(:shift).permit(:date, :end_date, :start_time, :end_time, :user_id, :sector_id, :team_id)
  end
end
