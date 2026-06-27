class ShiftsController < ApplicationController
  before_action :set_shift, only: %i[show edit update destroy]

  def index
    authorize Shift
    @shifts = policy_scope(Shift).includes(:user, sector: { team: :event }).order(:date, :start_time)
  end

  def show
    authorize @shift
  end

  def new
    authorize Shift
    @shift = Shift.new(sector_id: params[:sector_id])
  end

  def create
    authorize Shift
    @shift = Shift.new(shift_params)
    if @shift.save
      redirect_to shifts_path, notice: t("notices.created", model: Shift.model_name.human)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @shift
  end

  def update
    authorize @shift
    if @shift.update(shift_params)
      redirect_to shifts_path, notice: t("notices.updated", model: Shift.model_name.human)
    else
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

  def shift_params
    params.require(:shift).permit(:date, :start_time, :end_time, :has_radio, :user_id, :sector_id)
  end
end
