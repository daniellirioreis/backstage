class AttendancesController < ApplicationController
  before_action :set_event

  def scan
    authorize :attendance, :scan?
    @attendances_today = Attendance.where(event: @event)
                                   .where("checked_in_at >= ?", Date.today.beginning_of_day)
                                   .includes(:user, :team)
                                   .order(checked_in_at: :desc)
                                   .limit(10)
  end

  def check_in
    authorize :attendance, :scan?
    code = params[:code].to_s.strip.upcase

    membership      = TeamMembership.find_by(credential_code: code)
    team_from_coord = Team.find_by(coordinator_credential_code: code) unless membership

    user = membership&.user || team_from_coord&.coordinator
    team = membership&.team || team_from_coord

    unless user
      return render json: { status: :not_found, message: "Credencial não encontrada (#{code})" }, status: :unprocessable_entity
    end

    attendance = Attendance.find_by(user: user, event: @event)

    if attendance
      return render json: {
        status:          :already_checked_in,
        message:         "Já registrado às #{I18n.l(attendance.checked_in_at, format: :short)}",
        user_name:       user.name,
        team_name:       attendance.team&.name,
        checked_in_at:   I18n.l(attendance.checked_in_at, format: :short),
        avatar_initials: user.name.split.map(&:first).first(2).join.upcase
      }
    end

    attendance = Attendance.create!(
      user:           user,
      event:          @event,
      team:           team,
      checked_in_by:  current_user,
      checked_in_at:  Time.current
    )

    render json: {
      status:          :ok,
      message:         "Presença registrada!",
      user_name:       user.name,
      team_name:       team&.name,
      checked_in_at:   I18n.l(attendance.checked_in_at, format: :short),
      avatar_initials: user.name.split.map(&:first).first(2).join.upcase
    }
  rescue => e
    Rails.logger.error "[check_in] #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
    render json: { status: :error, message: "#{e.class}: #{e.message}" }, status: :unprocessable_entity
  end

  def destroy
    attendance = Attendance.find(params[:id])
    authorize attendance
    attendance.destroy
    redirect_to attendances_path, notice: "Entrada de #{attendance.user.name} cancelada."
  end

  def index
    authorize :attendance, :index?

    scope = Attendance.where(event: @event)
                      .includes(:user, :checked_in_by, team: :sector)

    if params[:sector_id].present?
      scope = scope.joins(team: :sector).where(sectors: { id: params[:sector_id] })
    end

    @attendances = scope.order(checked_in_at: :desc)

    # Credential codes por user (membership ou coordenador)
    user_ids = @attendances.map { |a| a.user_id }
    @credential_codes = TeamMembership
      .joins(team: :sector)
      .where(sectors: { event_id: @event.id }, user_id: user_ids)
      .pluck(:user_id, :credential_code)
      .to_h

    # Coordenadores: pegar coordinator_credential_code da team
    coordinator_codes = Team
      .joins(:sector)
      .where(sectors: { event_id: @event.id }, coordinator_id: user_ids)
      .pluck(:coordinator_id, :coordinator_credential_code)
      .to_h

    @credential_codes = coordinator_codes.merge(@credential_codes)

    # Totais para estatísticas
    @total_collaborators = TeamMembership
      .joins(team: :sector)
      .where(sectors: { event_id: @event.id })
      .count +
      Team.joins(:sector).where(sectors: { event_id: @event.id }).where.not(coordinator_id: nil).count

    @sectors = Sector.where(event_id: @event.id).order(:name)
  end

  private

  def set_event
    @event = current_event
    return if @event

    # Para requisições AJAX/JSON, retorna erro em vez de redirecionar
    if request.format.json?
      render json: { status: :error, message: "Nenhum evento selecionado" }, status: :unprocessable_entity
    else
      redirect_to select_event_path, alert: "Selecione um evento."
    end
  end
end
