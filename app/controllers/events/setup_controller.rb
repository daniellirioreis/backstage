class Events::SetupController < ApplicationController
  before_action :set_event

  def sectors
    authorize @event, :edit?
    @sectors = @event.sectors.order(:created_at)
  end

  def save_sectors
    authorize @event, :edit?

    added = 0
    (params[:sectors] || []).each do |s|
      next if s[:name].blank?
      @event.sectors.create!(name: s[:name].strip, sector_type: s[:sector_type].presence)
      added += 1
    end

    redirect_to teams_event_setup_path(@event)
  rescue ActiveRecord::RecordInvalid => e
    @sectors = @event.sectors.reload.order(:created_at)
    flash.now[:alert] = e.message
    render :sectors, status: :unprocessable_entity
  end

  def teams
    authorize @event, :edit?
    @sectors = @event.sectors.includes(:teams).order(:created_at)

    if @sectors.empty?
      redirect_to sectors_event_setup_path(@event),
        alert: "Adicione pelo menos um setor antes de criar equipes."
    end
  end

  def save_teams
    authorize @event, :edit?

    (params[:teams] || []).each do |t|
      next if t[:name].blank? || t[:sector_id].blank?
      sector = @event.sectors.find_by(id: t[:sector_id])
      sector&.teams&.create(name: t[:name].strip)
    end

    redirect_to event_path(@event), notice: "Evento configurado com sucesso!"
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end
end
