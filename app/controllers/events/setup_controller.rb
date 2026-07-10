class Events::SetupController < ApplicationController
  before_action :set_event

  def sectors
    authorize @event, :edit?
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

      else
        # ── Setor novo: criar ──────────────────────────────────────────────
        next if s[:name].blank?
        sector = @event.sectors.create!(name: s[:name].strip, sector_type: s[:sector_type].presence)

        (s[:functions] || {}).each_value do |fn|
          qty = fn[:quantity].to_i
          next if qty <= 0 || fn[:event_function_id].blank?
          sector.sector_functions.create!(event_function_id: fn[:event_function_id], quantity: qty)
        end
      end
    end

    redirect_to teams_event_setup_path(@event)
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

    if @sectors.empty?
      redirect_to sectors_event_setup_path(@event),
        alert: "Adicione pelo menos um setor antes de criar equipes."
    end
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

    team_ids = @sectors.flat_map { |s| s.teams.map(&:id) }
    @users_with_shift_by_team = Shift.where(team_id: team_ids)
                                     .distinct
                                     .group(:team_id)
                                     .count(:user_id)
    @event_days = @event.event_days.ordered
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
    saved_teams.each do |team|
      team.reload
      raise ActiveRecord::RecordInvalid.new(team) unless team.valid?
    end

    redirect_to schedules_event_setup_path(@event), notice: "Equipes salvas! Agora configure as escalas."
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
