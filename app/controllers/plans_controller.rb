class PlansController < ApplicationController
  before_action :set_plan, only: %i[show edit update destroy]

  def index
    authorize Plan
    @plans = Plan.includes(:companies).order(:name)
  end

  def show
    authorize @plan
    @companies = @plan.companies.order(:name)
  end

  def new
    authorize Plan
    @plan = Plan.new
  end

  def create
    authorize Plan
    @plan = Plan.new(plan_params)
    if @plan.save
      redirect_to plans_path, notice: "Plano criado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @plan
  end

  def update
    authorize @plan
    if @plan.update(plan_params)
      redirect_to plans_path, notice: "Plano atualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @plan
    if @plan.companies.exists?
      redirect_to plans_path, alert: "Não é possível excluir: #{@plan.companies.count} empresa(s) neste plano."
    else
      @plan.destroy
      redirect_to plans_path, notice: "Plano excluído."
    end
  end

  private

  def set_plan
    @plan = Plan.find(params[:id])
  end

  def plan_params
    params.require(:plan).permit(:name, :price, :events_limit, :members_limit, :description)
  end
end
