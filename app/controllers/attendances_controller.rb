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

    # Busca primeiro por credencial diária (por dia), fallback no código legado
    membership = resolve_membership_from_code(code, Date.today)

    unless membership
      return render json: { status: :not_found, message: "Credencial não encontrada (#{code})" }, status: :unprocessable_entity
    end

    user = membership.user
    team = membership.team
    avatar_url = user.avatar.attached? ? url_for(user.avatar) : nil

    # Verifica escala do colaborador para hoje
    today       = Date.today
    now_minutes = Time.current.hour * 60 + Time.current.min

    yesterday = today - 1
    shifts_today = Shift.joins(:sector)
                        .where(sectors: { event_id: @event.id }, user_id: user.id)
                        .where(
                          "(shifts.date <= :today AND COALESCE(shifts.end_date, shifts.date) >= :today)" \
                          " OR (shifts.end_time < shifts.start_time AND shifts.date <= :yesterday AND COALESCE(shifts.end_date, shifts.date) >= :yesterday)",
                          today: today, yesterday: yesterday
                        )

    if shifts_today.exists?
      # Tem escala: verifica se está no horário
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
          status:          :out_of_schedule,
          message:         "Fora do horário de escala (#{ranges})",
          user_name:       user.name,
          team_name:       team&.name,
          avatar_initials: user.name.split.map(&:first).first(2).join.upcase,
          avatar_url:      avatar_url
        }, status: :unprocessable_entity
      end
    end
    # Sem escala (ex: substituto) → credencial válida, check-in liberado

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

    # Busca primeiro por credencial diária (por dia), fallback no código legado
    membership = resolve_membership_from_code(code, Date.today)

    unless membership
      return render json: { status: :not_found, message: "Credencial não encontrada (#{code})" }, status: :unprocessable_entity
    end

    user     = membership.user
    team     = membership.team
    avatar_url = user.avatar.attached? ? url_for(user.avatar) : nil
    initials   = user.name.split.map(&:first).first(2).join.upcase

    # Busca presença aberta de hoje ou ontem (cobre eventos noturnos que passam da meia-noite)
    attendance = Attendance.where(user: user, event: @event, checked_out_at: nil)
                           .where(checked_in_date: [Date.today, Date.yesterday])
                           .order(checked_in_at: :desc)
                           .first

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


  def manual_checkout
    attendance = Attendance.find(params[:id])
    authorize attendance, :checkout?
    date = params[:date].presence || attendance.checked_in_date
    if attendance.checked_out_at.present?
      redirect_to attendances_path(date: date, sector_id: params[:sector_id], inside: params[:inside], q: params[:q]),
        alert: "#{attendance.user.name} já possui checkout registrado."
    else
      attendance.update!(checked_out_at: Time.current, checked_out_by_id: current_user.id)
      redirect_to attendances_path(date: date, sector_id: params[:sector_id], inside: params[:inside], q: params[:q]),
        notice: "Checkout de #{attendance.user.name} registrado."
    end
  end

  def cancel_checkout
    attendance = Attendance.find(params[:id])
    authorize attendance, :destroy?
    date = params[:date].presence || attendance.checked_in_date
    attendance.update!(checked_out_at: nil, checked_out_by_id: nil)
    redirect_to attendances_path(date: date, sector_id: params[:sector_id], inside: params[:inside], q: params[:q]),
      notice: "Checkout de #{attendance.user.name} cancelado."
  end

  def destroy
    attendance = Attendance.find(params[:id])
    authorize attendance
    date = params[:date].presence || attendance.checked_in_date
    attendance.destroy
    redirect_to attendances_path(date: date, sector_id: params[:sector_id], inside: params[:inside], q: params[:q]),
      notice: "Check-in de #{attendance.user.name} cancelado."
  end

  def index
    authorize :attendance, :index?

    # ── Filtro de data ─────────────────────────────────────────────────────────
    @event_days    = EventDay.where(event: @event).order(:date)
    @selected_date = params[:date].present? ? (Date.parse(params[:date]) rescue nil) : nil
    @sectors       = Sector.where(event_id: @event.id).order(:name)

    # Sem data selecionada: não carrega nada, a view mostra instrução
    unless @selected_date
      @attendances         = Attendance.none
      @not_checked_in      = []
      @credential_codes    = {}
      @substitute_user_ids = Set.new
      @replaced_user_name  = {}
      @total_collaborators = 0
      @total_substitutes   = 0
      @shifts_today_by_user = {}
      @expected_end_by_user = {}
      return
    end

    scope = Attendance.where(event: @event, checked_in_date: @selected_date)
                      .includes(:user, :checked_in_by, team: :sector)

    if params[:sector_id].present?
      scope = scope.joins(team: :sector).where(sectors: { id: params[:sector_id] })
    end

    if params[:q].present?
      scope = scope.joins(:user).where("users.name ILIKE ?", "%#{params[:q].strip}%")
    end

    if params[:inside] == "1"
      scope = scope.where(checked_out_at: nil)
    elsif params[:inside] == "done"
      scope = scope.where.not(checked_out_at: nil)
    end

    @attendances = scope.order(checked_in_at: :desc)

    # Credential codes, substitutos e substituídos — carrega de uma vez para todos os membros do evento
    all_memberships = TeamMembership
      .joins(team: :sector)
      .where(sectors: { event_id: @event.id })
      .pluck(:user_id, :credential_code, :substitute, :replaced_user_id)

    @credential_codes    = all_memberships.to_h { |uid, code, _, _| [uid, code] }
    @substitute_user_ids = all_memberships.select { |_, _, sub, _| sub }.map(&:first).to_set

    # Mapa user_id → nome do substituído (quem o substituto está cobrindo)
    replaced_ids = all_memberships.filter_map { |_, _, _, rid| rid }.uniq
    replaced_names = replaced_ids.any? ? User.where(id: replaced_ids).pluck(:id, :name).to_h : {}
    @replaced_user_name = all_memberships.each_with_object({}) do |(uid, _, _, rid), h|
      h[uid] = replaced_names[rid] if rid.present?
    end

    # Totais para estatísticas (respeitam filtro de setor)
    membership_scope = TeamMembership.joins(team: :sector).where(sectors: { event_id: @event.id })
    membership_scope = membership_scope.where(sectors: { id: params[:sector_id] }) if params[:sector_id].present?
    @total_collaborators = membership_scope.distinct.count(:user_id)
    @total_substitutes   = membership_scope.where(substitute: true).distinct.count(:user_id)

    # Colaboradores escalados no dia selecionado mas sem check-in (respeita filtro de setor)
    shifts_today = Shift.joins(:sector)
                        .where(sectors: { event_id: @event.id })
                        .where("shifts.date <= :day AND COALESCE(shifts.end_date, shifts.date) >= :day", day: @selected_date)
                        .includes(:user, team: :sector)
    shifts_today = shifts_today.where(sectors: { id: params[:sector_id] }) if params[:sector_id].present?

    checked_in_user_ids = Attendance.where(event: @event, checked_in_date: @selected_date).pluck(:user_id).to_set

    # Shift completo por user (primeiro encontrado) — usado na listagem de check-ins
    @shifts_today_by_user = shifts_today.each_with_object({}) do |shift, h|
      h[shift.user_id] ||= shift
    end

    # Horário previsto de saída por user (primeiro shift encontrado)
    @expected_end_by_user = @shifts_today_by_user.transform_values(&:end_time)

    # Agrupa por user e monta lista de não chegaram
    from_shifts = shifts_today
      .reject { |s| checked_in_user_ids.include?(s.user_id) }
      .group_by(&:user_id)
      .map do |_uid, shifts|
        s = shifts.first
        {
          user:            s.user,
          team:            s.team,
          shifts:          shifts,
          credential_code: @credential_codes[s.user_id],
          substitute:      @substitute_user_ids.include?(s.user_id)
        }
      end

    # Membros sem escala que ainda não fizeram check-in (substitutos e regulares)
    shift_user_ids = from_shifts.map { |r| r[:user].id }.to_set
    no_shift_scope = TeamMembership
      .joins(team: :sector)
      .where(sectors: { event_id: @event.id })
      .where.not(user_id: checked_in_user_ids + shift_user_ids)
      .includes(:event_function, user: { avatar_attachment: :blob }, team: :sector)
    no_shift_scope = no_shift_scope.where(sectors: { id: params[:sector_id] }) if params[:sector_id].present?

    # Deduplica por user_id (membro em mais de uma equipe aparece uma vez)
    seen_ids = Set.new
    from_no_shift = no_shift_scope.each_with_object([]) do |tm, arr|
      next if seen_ids.include?(tm.user_id)
      seen_ids.add(tm.user_id)
      arr << {
        user:            tm.user,
        team:            tm.team,
        shifts:          [],
        credential_code: @credential_codes[tm.user_id],
        substitute:      @substitute_user_ids.include?(tm.user_id)
      }
    end

    @not_checked_in = (from_shifts + from_no_shift).sort_by { |r| r[:user].name }
  end

  private

  # Resolve TeamMembership a partir de um código de credencial.
  # Primeiro tenta DailyCredential (código por dia); se não encontrar,
  # cai no código legado direto em TeamMembership (retrocompatibilidade).
  def resolve_membership_from_code(code, date)
    daily_cred = DailyCredential
      .includes(team_membership: { user: { avatar_attachment: :blob } })
      .find_by(credential_code: code, date: date)

    daily_cred&.team_membership ||
      TeamMembership.includes(user: { avatar_attachment: :blob }).find_by(credential_code: code)
  end

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
