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

    membership      = TeamMembership.includes(user: { avatar_attachment: :blob }).find_by(credential_code: code)
    team_from_coord = Team.includes(coordinator: { avatar_attachment: :blob }).find_by(coordinator_credential_code: code) unless membership

    user = membership&.user || team_from_coord&.coordinator
    team = membership&.team || team_from_coord

    unless user
      return render json: { status: :not_found, message: "Credencial não encontrada (#{code})" }, status: :unprocessable_entity
    end

    avatar_url = user.avatar.attached? ? url_for(user.avatar) : nil

    # Verifica escala do colaborador para hoje
    today       = Date.today
    now_minutes = Time.current.hour * 60 + Time.current.min

    yesterday = today - 1
    shifts_today = Shift.joins(:sector)
                        .where(sectors: { event_id: @event.id }, user_id: user.id)
                        .where(
                          "(shifts.date <= :today AND (shifts.end_date IS NULL OR shifts.end_date >= :today))" \
                          " OR (shifts.end_time < shifts.start_time AND shifts.date <= :yesterday AND (shifts.end_date IS NULL OR shifts.end_date >= :yesterday))",
                          today: today, yesterday: yesterday
                        )

    unless shifts_today.exists?
      return render json: {
        status:    :no_shift_today,
        message:   "#{user.name.split.first} não tem escala cadastrada para hoje (#{I18n.l(today, format: :short)})",
        user_name: user.name,
        team_name: team&.name,
        avatar_initials: user.name.split.map(&:first).first(2).join.upcase,
        avatar_url: avatar_url
      }, status: :unprocessable_entity
    end

    in_schedule = shifts_today.any? do |s|
      s_min = s.start_time.hour * 60 + s.start_time.min
      e_min = s.end_time.hour   * 60 + s.end_time.min
      if e_min < s_min # overnight
        now_minutes >= s_min || now_minutes < e_min
      else
        now_minutes >= s_min && now_minutes < e_min
      end
    end

    unless in_schedule
      ranges = shifts_today.map { |s| "#{s.start_time.strftime('%H:%M')}–#{s.end_time.strftime('%H:%M')}" }.join(", ")
      return render json: {
        status:    :out_of_schedule,
        message:   "Fora do horário de escala (#{ranges})",
        user_name: user.name,
        team_name: team&.name,
        avatar_initials: user.name.split.map(&:first).first(2).join.upcase,
        avatar_url: avatar_url
      }, status: :unprocessable_entity
    end

    attendance = Attendance.find_by(user: user, event: @event, checked_in_date: today)

    if attendance
      return render json: {
        status:          :already_checked_in,
        message:         "Já registrado hoje às #{I18n.l(attendance.checked_in_at, format: :time_only)}",
        user_name:       user.name,
        team_name:       attendance.team&.name,
        checked_in_at:   I18n.l(attendance.checked_in_at, format: :short),
        avatar_initials: user.name.split.map(&:first).first(2).join.upcase,
        avatar_url:      avatar_url
      }
    end

    attendance = Attendance.create!(
      user:            user,
      event:           @event,
      team:            team,
      checked_in_by:   current_user,
      checked_in_at:   Time.current,
      checked_in_date: today
    )

    render json: {
      status:          :ok,
      message:         "Presença registrada!",
      user_name:       user.name,
      team_name:       team&.name,
      checked_in_at:   I18n.l(attendance.checked_in_at, format: :short),
      avatar_initials: user.name.split.map(&:first).first(2).join.upcase,
      avatar_url:      avatar_url
    }
  rescue => e
    Rails.logger.error "[check_in] #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
    render json: { status: :error, message: "#{e.class}: #{e.message}" }, status: :unprocessable_entity
  end

  def check_out
    authorize :attendance, :checkout?
    code = params[:code].to_s.strip.upcase

    membership      = TeamMembership.includes(user: { avatar_attachment: :blob }).find_by(credential_code: code)
    team_from_coord = Team.includes(coordinator: { avatar_attachment: :blob }).find_by(coordinator_credential_code: code) unless membership

    user = membership&.user || team_from_coord&.coordinator
    team = membership&.team || team_from_coord

    unless user
      return render json: { status: :not_found, message: "Credencial não encontrada (#{code})" }, status: :unprocessable_entity
    end

    avatar_url = user.avatar.attached? ? url_for(user.avatar) : nil
    initials   = user.name.split.map(&:first).first(2).join.upcase

    attendance = Attendance.find_by(user: user, event: @event, checked_in_date: Date.today)

    unless attendance
      return render json: {
        status:          :not_checked_in,
        message:         "#{user.name.split.first} ainda não realizou check-in hoje",
        user_name:       user.name,
        team_name:       team&.name,
        avatar_initials: initials,
        avatar_url:      avatar_url
      }, status: :unprocessable_entity
    end

    if attendance.checked_out_at.present?
      return render json: {
        status:          :already_checked_out,
        message:         "Checkout já registrado às #{I18n.l(attendance.checked_out_at, format: :time_only)}",
        user_name:       user.name,
        team_name:       team&.name,
        checked_out_at:  I18n.l(attendance.checked_out_at, format: :short),
        avatar_initials: initials,
        avatar_url:      avatar_url
      }
    end

    attendance.update!(
      checked_out_at:    Time.current,
      checked_out_by_id: current_user.id
    )

    render json: {
      status:          :ok,
      message:         "Checkout registrado!",
      user_name:       user.name,
      team_name:       team&.name,
      checked_out_at:  I18n.l(attendance.checked_out_at, format: :short),
      avatar_initials: initials,
      avatar_url:      avatar_url
    }
  rescue => e
    render json: { status: :error, message: "#{e.class}: #{e.message}" }, status: :unprocessable_entity
  end

  def cancel_checkout
    attendance = Attendance.find(params[:id])
    authorize attendance, :destroy?
    attendance.update!(checked_out_at: nil, checked_out_by_id: nil)
    redirect_to attendances_path, notice: "Checkout de #{attendance.user.name} cancelado."
  end

  def destroy
    attendance = Attendance.find(params[:id])
    authorize attendance
    attendance.destroy
    redirect_to attendances_path, notice: "Check-in de #{attendance.user.name} cancelado."
  end

  def index
    authorize :attendance, :index?

    scope = Attendance.where(event: @event)
                      .includes(:user, :checked_in_by, team: :sector)

    if params[:sector_id].present?
      scope = scope.joins(team: :sector).where(sectors: { id: params[:sector_id] })
    end

    if params[:inside] == "1"
      scope = scope.where(checked_out_at: nil)
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
