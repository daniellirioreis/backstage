class Events::SetupController < ApplicationController
  before_action :set_event

  def sectors
    authorize @event, :edit?
    missing = step1_missing(@event)
    if missing.any?
      redirect_to edit_event_path(@event),
        alert: "Preencha os dados obrigatórios antes de continuar: #{missing.join(', ')}."
      return
    end
    @sectors         = @event.sectors.order(:created_at)
    @event_functions = @event.event_functions.order(:name)
    @event_hours     = event_hours_for(@event)
  end

  def save_sectors
    authorize @event, :edit?

    (params[:sectors] || {}).each_value do |s|
      if s[:id].present?
        # ── Setor existente: atualizar ou deletar ──────────────────────────
        sector = @event.sectors.find_by(id: s[:id])
        next unless sector

        if s[:_destroy] == "1"
          sector.destroy
          next
        end

        next if s[:name].blank?
        sector.update!(name: s[:name].strip, sector_type: s[:sector_type].presence)

        # Substitui funções pelo que veio no form
        sector.sector_functions.destroy_all
        (s[:functions] || {}).each_value do |fn|
          qty = fn[:quantity].to_i
          next if qty <= 0 || fn[:event_function_id].blank?
          sector.sector_functions.create!(event_function_id: fn[:event_function_id], quantity: qty)
        end

        if @event.event_functions.any? && sector.sector_functions.reload.empty?
          sector.errors.add(:base, "O setor \"#{sector.name}\" precisa ter pelo menos uma função planejada.")
          raise ActiveRecord::RecordInvalid.new(sector)
        end

      else
        # ── Setor novo: criar ──────────────────────────────────────────────
        next if s[:name].blank?
        sector = @event.sectors.create!(name: s[:name].strip, sector_type: s[:sector_type].presence)

        (s[:functions] || {}).each_value do |fn|
          qty = fn[:quantity].to_i
          next if qty <= 0 || fn[:event_function_id].blank?
          sector.sector_functions.create!(event_function_id: fn[:event_function_id], quantity: qty)
        end

        if @event.event_functions.any? && sector.sector_functions.reload.empty?
          sector.errors.add(:base, "O setor \"#{sector.name}\" precisa ter pelo menos uma função planejada.")
          raise ActiveRecord::RecordInvalid.new(sector)
        end
      end
    end

    if params[:commit] == "save_and_stay"
      redirect_to sectors_event_setup_path(@event), notice: "Setor salvo!"
    else
      incomplete = sectors_step_incomplete(@event)
      if incomplete.any?
        redirect_to sectors_event_setup_path(@event),
          alert: "Preencha nome e tipo em todos os setores antes de continuar: #{incomplete.join(', ')}."
      else
        redirect_to teams_event_setup_path(@event)
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    @sectors         = @event.sectors.reload.order(:created_at)
    @event_functions = @event.event_functions.order(:name)
    @event_hours     = event_hours_for(@event)
    flash.now[:alert] = e.message
    render :sectors, status: :unprocessable_entity
  end

  def teams
    authorize @event, :edit?
    @sectors         = @event.sectors
                             .includes({ teams: { team_memberships: :user } }, sector_functions: :event_function)
                             .order(:created_at)
    @event_functions = @event.event_functions.order(:name)
    @roles           = Role.order(:name)

    if @sectors.empty?
      redirect_to sectors_event_setup_path(@event),
        alert: "Adicione pelo menos um setor antes de criar equipes."
      return
    end

    incomplete = sectors_step_incomplete(@event)
    if incomplete.any?
      redirect_to sectors_event_setup_path(@event),
        alert: "Preencha nome e tipo em todos os setores antes de continuar: #{incomplete.join(', ')}."
    end
  end

  # POST AJAX: cria colaborador rápido e associa à empresa do evento
  def quick_add_collaborator
    authorize @event, :edit?

    role = Role.find_by(id: params[:role_id])
    unless role
      return render json: { error: "Perfil não encontrado." }, status: :unprocessable_entity
    end

    user = User.new(
      name:     params[:name].to_s.strip,
      cpf:      params[:cpf].to_s.strip,
      phone:    params[:phone].to_s.strip,
      role:     role,
      email:    "user.#{SecureRandom.hex(6)}@backstage.tmp",
      password: SecureRandom.hex(16)
    )

    unless user.save
      return render json: { error: user.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end

    company = @event.company
    CompanyUser.find_or_create_by!(user: user, company: company) if company

    render json: {
      id:       user.id,
      name:     user.name,
      phone:    user.phone,
      initials: user.name.split.map(&:first).first(2).join.upcase
    }
  end

  # AJAX: eventos da mesma empresa (exceto o atual) para o seletor do modal
  def import_source_events
    authorize @event, :edit?
    events = Event.where(company_id: @event.company_id)
                  .where.not(id: @event.id)
                  .order(start_date: :desc)
                  .limit(30)
    render json: events.map { |e|
      { id: e.id, name: e.name, date: e.start_date&.strftime("%d/%m/%Y") }
    }
  end

  # AJAX: equipes + membros de um evento origem, agrupados por setor
  def import_source_sector_teams
    authorize @event, :edit?
    source = Event.find(params[:source_event_id])
    data = source.sectors
                 .includes(teams: { team_memberships: [:user, :event_function] })
                 .order(:name)
                 .map do |s|
      {
        sector_name: s.name,
        teams: s.teams.order(:name).map do |t|
          {
            id:      t.id,
            name:    t.name,
            members: t.team_memberships
                       .joins(:user)
                       .order("users.name")
                       .map { |tm|
                         {
                           user_id:       tm.user_id,
                           name:          tm.user.name,
                           function_name: tm.event_function&.name,
                           coordinator:   tm.coordinator?
                         }
                       }
          }
        end
      }
    end
    render json: data
  end

  # POST: importa equipes + colaboradores selecionados para um setor do evento atual
  def import_teams
    authorize @event, :edit?
    sector = @event.sectors.find(params[:sector_id])

    # params[:imports] = { "0" => { source_team_id:, user_ids: [] }, ... }
    imported_teams = 0
    imported_members = 0

    (params[:imports] || {}).each_value do |entry|
      src_team = Team.find_by(id: entry[:source_team_id])
      next unless src_team

      team = sector.teams.find_or_initialize_by(name: src_team.name)
      team.radio_channel ||= src_team.radio_channel
      team.save!
      imported_teams += 1 if team.previously_new_record?

      Array(entry[:user_ids]).each do |uid|
        next if team.team_memberships.exists?(user_id: uid)
        team.team_memberships.create!(user_id: uid)
        imported_members += 1
      end
    end

    redirect_to teams_event_setup_path(@event),
      notice: "#{imported_teams} equipe(s) criada(s), #{imported_members} colaborador(es) importado(s) para "#{sector.name}"."
  end

  def schedules
    authorize @event, :edit?
    @sectors = @event.sectors
                     .includes(teams: { team_memberships: :user })
                     .order(:created_at)

    if @sectors.empty?
      redirect_to sectors_event_setup_path(@event),
        alert: "Adicione pelo menos um setor antes de configurar escalas."
      return
    end

    incomplete = teams_step_incomplete(@event)
    if incomplete.any?
      redirect_to teams_event_setup_path(@event),
        alert: "Preencha os dados obrigatórios em todas as equipes antes de continuar: #{incomplete.join(', ')}."
      return
    end

    team_ids = @sectors.flat_map { |s| s.teams.map(&:id) }
    @users_with_shift_by_team = Shift.where(team_id: team_ids)
                                     .distinct
                                     .group(:team_id)
                                     .count(:user_id)
    @event_days = @event.event_days.ordered
  end

  def finish
    authorize @event, :edit?

    team_ids = @event.sectors.includes(:teams).flat_map { |s| s.teams.map(&:id) }

    if team_ids.empty?
      redirect_to teams_event_setup_path(@event),
        alert: "Adicione equipes antes de finalizar."
      return
    end

    teams_with_shifts = Shift.where(team_id: team_ids).distinct.pluck(:team_id)
    teams_without     = Team.where(id: team_ids - teams_with_shifts).pluck(:name)

    if teams_without.any?
      redirect_to schedules_event_setup_path(@event),
        alert: "Configure as escalas de todas as equipes antes de finalizar: #{teams_without.to_sentence(locale: :pt)}."
    else
      redirect_to event_path(@event), notice: "Configuração concluída!"
    end
  end

  def save_teams
    authorize @event, :edit?

    saved_teams = []

    (params[:teams] || {}).each_value do |t|
      if t[:id].present?
        # ── Equipe existente: atualizar ou deletar ─────────────────────────
        sector = @event.sectors.find_by(id: t[:sector_id])
        next unless sector
        team = sector.teams.find_by(id: t[:id])
        next unless team

        if t[:_destroy] == "1"
          team.destroy
          next
        end

        next if t[:name].blank?
        # Pula a validação de unicidade de membros durante o loop — os dados ainda
        # estão no estado antigo (antes do destroy_all/recriação). Valida no final.
        team.skip_member_uniqueness_check = true
        team.update!(
          name:           t[:name].strip,
          coordinator_id: t[:coordinator_id].presence,
          radio_channel:  t[:radio_channel].presence
        )

        team.team_memberships.destroy_all
        (t[:members] || {}).each_value do |m|
          next if m[:user_id].blank?
          next if m[:user_id].to_s == t[:coordinator_id].to_s  # coordenador nunca como :member
          team.team_memberships.create(
            user_id:           m[:user_id],
            event_function_id: m[:event_function_id].presence
          )
        end
        # destroy_all wipes the coordinator's :coordinator membership; re-ensure it
        ensure_coordinator_membership(team)
        saved_teams << team

      else
        # ── Equipe nova: criar ─────────────────────────────────────────────
        next if t[:name].blank? || t[:sector_id].blank?
        sector = @event.sectors.find_by(id: t[:sector_id])
        next unless sector

        team = sector.teams.new(
          name:           t[:name].strip,
          coordinator_id: t[:coordinator_id].presence,
          radio_channel:  t[:radio_channel].presence
        )
        team.skip_member_uniqueness_check = true
        team.save!

        (t[:members] || {}).each_value do |m|
          next if m[:user_id].blank?
          next if m[:user_id].to_s == t[:coordinator_id].to_s  # coordenador nunca como :member
          team.team_memberships.create(
            user_id:           m[:user_id],
            event_function_id: m[:event_function_id].presence
          )
        end
        # sync_coordinator_membership fires on create, but the member loop may have
        # added the coordinator again as :member — ensure correct role and no duplicates
        ensure_coordinator_membership(team)
        saved_teams << team
      end
    end

    # ── Validação final com membros no estado correto ──────────────────────
    has_functions = @event.event_functions.any?

    saved_teams.each do |team|
      team.reload
      raise ActiveRecord::RecordInvalid.new(team) unless team.valid?

      members = team.team_memberships.reject(&:coordinator?)

      if members.empty?
        team.errors.add(:base, "A equipe \"#{team.name}\" precisa ter pelo menos um colaborador.")
        raise ActiveRecord::RecordInvalid.new(team)
      end

      if has_functions && members.any? { |tm| tm.event_function_id.blank? }
        team.errors.add(:base, "Todos os colaboradores da equipe \"#{team.name}\" precisam ter uma função informada.")
        raise ActiveRecord::RecordInvalid.new(team)
      end
    end

    if params[:commit] == "save_and_stay"
      redirect_to teams_event_setup_path(@event, sector_id: params[:active_sector_id]), notice: "Equipe salva!"
    else
      incomplete = teams_step_incomplete(@event)
      if incomplete.any?
        redirect_to teams_event_setup_path(@event),
          alert: "Preencha os dados obrigatórios em todas as equipes antes de continuar: #{incomplete.join(', ')}."
      else
        redirect_to schedules_event_setup_path(@event), notice: "Equipes salvas! Agora configure as escalas."
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    @sectors         = @event.sectors
                             .includes({ teams: { team_memberships: :user } }, sector_functions: :event_function)
                             .order(:created_at)
    @event_functions = @event.event_functions.order(:name)
    flash.now[:alert] = e.message
    render :teams, status: :unprocessable_entity
  end

  private

  # After destroy_all + recreate or after create (where sync_coordinator_membership
  # runs before the member loop), the coordinator's membership may be missing or
  # have :member role. This ensures exactly one :coordinator membership exists.
  def ensure_coordinator_membership(team)
    return if team.coordinator_id.blank?

    # Remove duplicates (can happen on new team: sync creates one, loop creates another)
    team.team_memberships
        .where(user_id: team.coordinator_id)
        .order(:created_at)
        .offset(1)
        .destroy_all

    # Create or upgrade the remaining membership to :coordinator
    tm = team.team_memberships.find_or_initialize_by(user_id: team.coordinator_id)
    tm.role = :coordinator
    tm.save!
  end

  def teams_step_incomplete(event)
    all_teams = event.sectors
                     .includes(teams: :team_memberships)
                     .flat_map(&:teams)
    return ["pelo menos uma equipe"] if all_teams.empty?

    has_functions = event.event_functions.any?
    issues = []

    all_teams.each do |team|
      label = team.name.presence || "(sem nome)"
      issues << "#{label} (sem nome)"        if team.name.blank?
      members = team.team_memberships.reject(&:coordinator?)
      issues << "#{label} (sem colaboradores)" if members.empty?
      if has_functions && members.any? { |tm| tm.event_function_id.blank? }
        issues << "#{label} (colaborador sem função)"
      end
    end

    issues
  end

  def sectors_step_incomplete(event)
    event.sectors.includes(:sector_functions).reload
         .select { |s| s.name.blank? || s.sector_type.blank? || s.sector_functions.empty? }
         .map { |s| s.name.presence || "(sem nome)" }
  end

  def step1_missing(event)
    missing = []
    missing << "nome do evento"        if event.name.blank?
    missing << "data de início"        if event.start_date.blank?
    missing << "data de término"       if event.end_date.blank?
    missing << "local"                 if event.location.blank?
    missing << "tipo de evento"        if event.event_type.blank?
    missing << "pelo menos um dia"     if event.event_days.none?
    missing << "pelo menos uma função" if event.event_functions.none?
    missing
  end

  def set_event
    @event = Event.find(params[:event_id])
  end

  def event_hours_for(event)
    total = event.total_hours
    return total if total > 0
    return 8.0 unless event.start_date && event.end_date
    ((event.end_date - event.start_date).to_i + 1) * 8.0
  end
end
