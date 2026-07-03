class SectorsController < ApplicationController
  before_action :set_sector, only: %i[edit update destroy]

  def index
    return redirect_to(select_event_path, alert: "Selecione um evento para continuar.") unless current_event
    authorize Sector
    @sectors = policy_scope(Sector).includes(:event, :sector_functions, teams: :users)
                                   .where(event_id: current_event.id)
                                   .order(:name)
                                   .paginate(page: params[:page], per_page: 10)
  end

  def new
    authorize Sector
    @sector = Sector.new(event_id: current_event.id)
    @sector.sector_functions.build
    @event_functions    = current_event.event_functions.order(:name)
    @event_days         = event_days_for(current_event)
    @assigned_fn_counts = {}
  end

  def create
    authorize Sector
    @sector = Sector.new(sector_params)
    @sector.event_id = current_event.id
    if @sector.save
      redirect_to sectors_path, notice: t("notices.created", model: Sector.model_name.human)
    else
      @event_functions    = current_event.event_functions.order(:name)
      @event_days         = event_days_for(current_event)
      @assigned_fn_counts = {}
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @sector
    @sector.sector_functions.build if @sector.sector_functions.empty?
    @event_functions    = @sector.event.event_functions.order(:name)
    @event_days         = event_days_for(@sector.event)
    @assigned_fn_counts = assigned_fn_counts_for(@sector)
  end

  def update
    authorize @sector
    if @sector.update(sector_params)
      redirect_to sectors_path, notice: t("notices.updated", model: Sector.model_name.human)
    else
      @event_functions    = @sector.event.event_functions.order(:name)
      @event_days         = event_days_for(@sector.event)
      @assigned_fn_counts = assigned_fn_counts_for(@sector)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @sector
    @sector.destroy
    redirect_to sectors_path, notice: t("notices.destroyed", model: Sector.model_name.human)
  end

  private

  def set_sector
    @sector = Sector.find(params[:id])
  end

  def assigned_fn_counts_for(sector)
    TeamMembership
      .joins(team: :sector)
      .where(teams: { sector_id: sector.id })
      .where.not(event_function_id: nil)
      .group(:event_function_id)
      .count
      .transform_keys(&:to_s)
  end

  def event_days_for(event)
    return 8.0 unless event
    total = event.total_hours
    return total if total > 0
    # fallback enquanto event_days ainda não foi preenchido
    return 8.0 unless event.start_date && event.end_date
    ((event.end_date - event.start_date).to_i + 1) * 8.0
  end

  def sector_params
    params.require(:sector).permit(
      :name, :event_id, :sector_type,
      sector_functions_attributes: [:id, :event_function_id, :quantity, :_destroy]
    )
  end
end
