class VehiclesController < ApplicationController
  before_action :set_vehicle, only: %i[show edit update destroy]

  def index
    authorize Vehicle
    @q_plate = params[:plate].to_s.strip
    @q_model = params[:model].to_s.strip
    @q_color = params[:color].to_s.strip

    @vehicles = policy_scope(Vehicle)
                  .then { |s| @q_plate.present? ? s.where("license_plate ILIKE ?", "%#{@q_plate}%") : s }
                  .then { |s| @q_model.present? ? s.where("model ILIKE ?", "%#{@q_model}%") : s }
                  .then { |s| @q_color.present? ? s.where("color ILIKE ?", "%#{@q_color}%") : s }
                  .order(:license_plate)
                  .paginate(page: params[:page], per_page: 10)
  end

  def show
    authorize @vehicle
  end

  def new
    authorize Vehicle
    @vehicle = Vehicle.new
  end

  def create
    authorize Vehicle
    @vehicle = Vehicle.new(vehicle_params)
    if @vehicle.save
      redirect_to vehicles_path, notice: t("notices.created", model: Vehicle.model_name.human)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @vehicle
  end

  def update
    authorize @vehicle
    if @vehicle.update(vehicle_params)
      redirect_to vehicles_path, notice: t("notices.updated", model: Vehicle.model_name.human)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @vehicle
    @vehicle.destroy
    redirect_to vehicles_path, notice: t("notices.destroyed", model: Vehicle.model_name.human)
  end

  private

  def set_vehicle
    @vehicle = Vehicle.find(params[:id])
  end

  def vehicle_params
    params.require(:vehicle).permit(:model, :color, :license_plate)
  end
end
