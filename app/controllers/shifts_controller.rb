class ShiftsController < ApplicationController
  before_action :set_shift, only: %i[show edit update destroy]

  def index
    return redirect_to(select_event_path, alert: "Selecione um evento para continuar.") unless current_event
    authorize Shift
    shifts = policy_scope(Shift)
               .joins(:sector)
               .where(sectors: { event_id: current_event.id })
               .includes(:user, { team: [:coordinator, :sector] }, :sector)
               .order(:date, :start_time)
    @shifts_by_team = shifts.group_by(&:team)

    team_ids = @shifts_by_team.keys.compact.map(&:id)
    @credential_map = TeamMembership.where(team_id: team_ids)
                                    .each_with_object({}) do |tm, h|
      h[[tm.team_id, tm.user_id]] = tm.full_credential_code
    end
  end

  def timeline
    authorize Shift, :timeline?
    @event = current_event

    # Data selecionada (default: primeiro dia do evento ou hoje)
    @date = params[:date].present? ? Date.parse(params[:date]) : (@event&.start_date || Date.today)

    # Turnos do dia filtrados pelo evento atual
    # Regras:
    #   1. Turno de dia único (sem end_date, não-overnight): apenas no seu date
    #   2. Turno overnight de dia único (sem end_date, end_time < start_time): no seu date E no dia seguinte
    #   3. Turno multi-dia (com end_date): em todos os dias entre date e end_date
    yesterday = @date - 1
    shifts = policy_scope(Shift)
               .joins(team: :sector)
               .where(sectors: { event_id: @event&.id })
               .includes(:user, { team: [:coordinator, :sector] })
               .where(
                 "(shifts.end_date IS NULL AND shifts.date = :date)" \
                 " OR (shifts.end_date IS NULL AND shifts.end_time < shifts.start_time AND shifts.date = :yesterday)" \
                 " OR (shifts.end_date IS NOT NULL AND shifts.date <= :date AND shifts.end_date >= :date)",
                 date: @date, yesterday: yesterday
               )
               .order(:start_time)

    # Modo de visualização: setores (padrão) ou colaboradores
    @view_mode = params[:view].presence || "sectors"

    # Agrupa por setor → equipe → lista de turnos
    @sectors_data = shifts.group_by { |s| s.team&.sector }.reject { |s, _| s.nil? }.sort_by { |s, _| s.name }
    @sectors_data = @sectors_data.map do |sector, sector_shifts|
      teams_data = sector_shifts.group_by(&:team).sort_by { |t, _| t.name }
      [sector, teams_data]
    end

    # Índice de cores dos setores (para usar na view de colaboradores)
    @sector_color_index = @sectors_data.each_with_index.map { |(sector, _), i| [sector.id, i] }.to_h

    # Agrupa por colaborador → lista de turnos (ordenada por start_time)
    @users_data = shifts.group_by(&:user).reject { |u, _| u.nil? }
                        .sort_by { |u, _| u.name }
                        .map { |u, u_shifts| [u, u_shifts.sort_by { |s| s.start_time.hour * 60 + s.start_time.min }] }

    # IDs dos colaboradores que já fizeram check-in neste evento
    @checked_in_ids = @event ? Attendance.where(event: @event).pluck(:user_id).to_set : Set.new

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
    @credential_map = TeamMembership.where(team_id: team_ids)
                                    .each_with_object({}) do |tm, h|
      h[[tm.team_id, tm.user_id]] = tm.full_credential_code
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
    @shift  = Shift.new
    @event  = current_event
    @teams  = Team.joins(:sector)
                  .where(sectors: { event_id: @event&.id })
                  .includes(:sector)
                  .order("sectors.name, teams.name")
    @event_days = @event ? @event.event_days.ordered : []

    if params[:team_id].present?
      @selected_team = Team.includes(sector: :event).find_by(id: params[:team_id])
      @team_members  = TeamMembership.where(team_id: @selected_team.id)
                                     .includes(:event_function, user: { avatar_attachment: :blob })
                                     .joins(:user)
                                     .order("users.name")
      @selected_days = resolve_selected_days(@event_days, params[:date], params[:end_date])
      # Aviso de escala existente só quando não há modo por-dia
      @team_has_shifts = @selected_days.empty? && Shift.where(team_id: @selected_team.id).exists?
    end
  end

  def create
    authorize Shift
    team = Team.find_by(id: params[:team_id])
    return redirect_to(new_shift_path, alert: "Selecione uma equipe.") unless team

    members = params[:members] || {}

    # Detecta modo por-dia: params têm data ISO como sub-chave dos membros
    per_day = members.values.first&.keys&.any? { |k| k.to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/) }

    if per_day
      created, failures, skipped = create_per_day(team, members)
    else
      # Modo legado: bloqueio se equipe já tem escala
      if Shift.where(team_id: team.id).exists?
        return params[:modal] == "1" ?
          render(html: "<script>alert('\"#{team.name}\" já possui escala.'); window.parent.closeShiftModal(); window.parent.location.reload();</script>".html_safe, layout: false) :
          redirect_to(new_shift_path(team_id: team.id), alert: "\"#{team.name}\" já possui escala definida.")
      end
      created, failures, skipped = create_legacy(team, members, params[:date], params[:end_date].presence)
    end

    if failures.any?
      @event           = current_event
      @event_days      = @event ? @event.event_days.ordered : []
      @teams           = Team.joins(:sector).where(sectors: { event_id: @event&.id }).includes(:sector).order("sectors.name, teams.name")
      @selected_team   = team
      @team_members    = TeamMembership.where(team_id: team.id).includes(:event_function, user: { avatar_attachment: :blob }).joins(:user).order("users.name")
      @selected_days   = resolve_selected_days(@event_days, params[:date], params[:end_date])
      @submitted_members = members
      @shift_errors    = failures
      @shift_created   = created
      @shift_skipped   = skipped
      render :new, status: :unprocessable_entity
    elsif created == 0
      redirect_to new_shift_path(date: params[:date], end_date: params[:end_date], team_id: team.id, modal: params[:modal]),
        alert: "Nenhum turno foi salvo.#{skipped.any? ? " Sem horário: #{skipped.join(', ')}." : ''}"
    else
      msg = "Escala de \"#{team.name}\" salva — #{created} turno(s) criado(s)."
      msg += " Sem horário (ignorados): #{skipped.join(', ')}." if skipped.any?
      if params[:modal] == "1"
        render html: "<script>window.parent.closeShiftModal(); window.parent.location.href='#{teams_path}?notice=#{CGI.escape(msg)}';</script>".html_safe, layout: false
      else
        redirect_to shifts_path, notice: msg
      end
    end
  end

  def edit_team
    authorize Shift, :edit?
    @event = current_event
    @selected_team = Team.includes(sector: :event).find(params[:team_id])
    @event_days = @event ? @event.event_days.ordered : []

    @team_members = TeamMembership
      .where(team_id: @selected_team.id)
      .includes(:event_function, user: { avatar_attachment: :blob })
      .joins(:user)
      .order("users.name")

    existing = Shift.where(team_id: @selected_team.id).order(:date)
    first    = existing.first

    @ref_date     = first&.date
    @ref_end_date = existing.maximum(:end_date) || existing.maximum(:date)
    @ref_end_date = nil if @ref_end_date == @ref_date

    # Usa params[:date]/[:end_date] quando o usuário confirmou seleção via GET
    date_str     = params[:date].presence     || @ref_date&.to_s
    end_date_str = params[:end_date].presence || @ref_end_date&.to_s
    @selected_days = resolve_selected_days(@event_days, date_str, end_date_str)

    # Indexado por [user_id, date_str] para suporte por-dia
    @existing_shifts = {}
    existing.each do |s|
      dates = s.end_date.present? ? (s.date..s.end_date).to_a : [s.date]
      dates.each { |d| @existing_shifts[[s.user_id, d.to_s]] = s }
    end
  end

  def update_team
    authorize Shift, :edit?
    @event = current_event
    @selected_team = Team.includes(sector: :event).find(params[:team_id])
    @event_days    = @event ? @event.event_days.ordered : []
    members        = params[:members] || {}

    per_day = members.values.first&.keys&.any? { |k| k.to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/) }

    if per_day
      # Apaga turnos dos dias selecionados e recria por-dia
      selected_dates = members.values.flat_map { |d| d.keys.grep(/\A\d{4}-\d{2}-\d{2}\z/) }.uniq
      Shift.where(team_id: @selected_team.id).each do |s|
        covered = s.end_date.present? ? (s.date..s.end_date).to_a.map(&:to_s) : [s.date.to_s]
        s.destroy if (covered & selected_dates).any?
      end
      created, failures, skipped = create_per_day(@selected_team, members)
      updated = 0
    else
      date     = params[:date]
      end_date = params[:end_date].presence
      updated, created_leg, failures, skipped = update_legacy(@selected_team, members, date, end_date)
      created = created_leg
    end

    if failures.any?
      @team_members = TeamMembership.where(team_id: @selected_team.id).includes(:event_function, user: { avatar_attachment: :blob }).joins(:user).order("users.name")
      existing = Shift.where(team_id: @selected_team.id).order(:date)
      @existing_shifts = {}
      existing.each do |s|
        dates = s.end_date.present? ? (s.date..s.end_date).to_a : [s.date]
        dates.each { |d| @existing_shifts[[s.user_id, d.to_s]] = s }
      end
      first = existing.first
      @ref_date  = first&.date
      @selected_days = resolve_selected_days(@event_days, @ref_date&.to_s, nil)
      @submitted_members = members
      @update_errors = failures
      render :edit_team, status: :unprocessable_entity
    else
      parts = []
      parts << "#{updated} atualizado(s)" if updated.to_i > 0
      parts << "#{created} criado(s)"     if created > 0
      parts << "Sem horário (ignorados): #{skipped.join(', ')}." if skipped.any?
      msg = "Escala de \"#{@selected_team.name}\" salva — #{parts.join(', ')}."
      if params[:modal] == "1"
        render html: "<script>window.parent.closeShiftModal(); window.parent.location.href='#{teams_path}?notice=#{CGI.escape(msg)}';</script>".html_safe, layout: false
      else
        redirect_to shifts_path, notice: msg
      end
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
    @all_users  = company_users_scope.order(:name)
  end

  def shift_params
    params.require(:shift).permit(:date, :end_date, :start_time, :end_time, :user_id, :sector_id, :team_id)
  end

  # Retorna os EventDay objects que correspondem ao intervalo date/end_date
  def resolve_selected_days(event_days, date_str, end_date_str)
    return [] if event_days.empty? || date_str.blank?
    start_d = Date.parse(date_str) rescue nil
    return [] unless start_d
    end_d = end_date_str.present? ? (Date.parse(end_date_str) rescue start_d) : start_d
    range = (start_d..end_d).to_a
    event_days.select { |ed| range.include?(ed.date) }
  end

  # Cria 1 Shift por colaborador por dia (modo por-dia)
  # members: { user_id => { "selected" => "1", "2026-07-03" => { start_time:, end_time: }, ... } }
  def create_per_day(team, members)
    created = 0; failures = []; skipped = []
    members.each do |user_id, user_data|
      next unless user_data["selected"] == "1"
      user_name = User.find_by(id: user_id)&.name
      day_entries = user_data.select { |k, _| k.to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/) }
      if day_entries.empty?
        skipped << user_name
        next
      end
      day_entries.each do |date_str, times|
        if times["start_time"].blank? || times["end_time"].blank?
          skipped << "#{user_name} (#{date_str})" unless skipped.include?("#{user_name} (#{date_str})")
          next
        end
        shift = Shift.new(
          user_id:    user_id,
          sector_id:  team.sector_id,
          team_id:    team.id,
          date:       date_str,
          end_date:   nil,
          start_time: times["start_time"],
          end_time:   times["end_time"]
        )
        if shift.save
          created += 1
        else
          Rails.logger.warn "[create_per_day] Falha ao salvar turno #{user_name} #{date_str}: #{shift.errors.full_messages.inspect}"
          failures << { name: "#{user_name} (#{date_str})", messages: shift.errors.full_messages }
        end
      end
    end
    [created, failures, skipped]
  end

  # Modo legado: 1 Shift por colaborador com date/end_date
  def create_legacy(team, members, date, end_date)
    created = 0; failures = []; skipped = []
    members.each do |user_id, data|
      next unless data["selected"] == "1"
      if data["start_time"].blank? || data["end_time"].blank?
        skipped << User.find_by(id: user_id)&.name; next
      end
      shift = Shift.new(user_id: user_id, sector_id: team.sector_id, team_id: team.id,
                        date: date, end_date: end_date,
                        start_time: data["start_time"], end_time: data["end_time"])
      shift.save ? (created += 1) : failures << { name: User.find_by(id: user_id)&.name, messages: shift.errors.full_messages }
    end
    [created, failures, skipped]
  end

  # Modo legado: atualiza/cria 1 Shift por colaborador
  def update_legacy(team, members, date, end_date)
    updated = 0; created = 0; failures = []; skipped = []
    members.each do |user_id, data|
      next unless data["selected"] == "1"
      if data["start_time"].blank? || data["end_time"].blank?
        skipped << User.find_by(id: user_id)&.name; next
      end
      attrs = { date: date, end_date: end_date, start_time: data["start_time"], end_time: data["end_time"] }
      existing = Shift.find_by(team_id: team.id, user_id: user_id)
      if existing
        existing.update(attrs) ? (updated += 1) : failures << { name: User.find_by(id: user_id)&.name, messages: existing.errors.full_messages }
      else
        s = Shift.new(attrs.merge(user_id: user_id, sector_id: team.sector_id, team_id: team.id))
        s.save ? (created += 1) : failures << { name: User.find_by(id: user_id)&.name, messages: s.errors.full_messages }
      end
    end
    [updated, created, failures, skipped]
  end
end
