class SectorFunctionsController < ApplicationController
  before_action :set_sector
  before_action :set_sector_function, only: [:update, :destroy]

  def create
    authorize @sector, :edit?
    @sector_function = @sector.sector_functions.new(sector_function_params)
    if @sector_function.save
      redirect_to edit_sector_path(@sector), notice: "Função adicionada ao planejamento."
    else
      redirect_to edit_sector_path(@sector), alert: @sector_function.errors.full_messages.to_sentence
    end
  end

  def update
    authorize @sector, :edit?
    if @sector_function.update(sector_function_params)
      redirect_to edit_sector_path(@sector), notice: "Quantidade atualizada."
    else
      redirect_to edit_sector_path(@sector), alert: @sector_function.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize @sector, :edit?
    @sector_function.destroy
    redirect_to edit_sector_path(@sector), notice: "Função removida do planejamento."
  end

  private

  def set_sector
    @sector = Sector.find(params[:sector_id])
  end

  def set_sector_function
    @sector_function = @sector.sector_functions.find(params[:id])
  end

  def sector_function_params
    params.require(:sector_function).permit(:event_function_id, :quantity)
  end
end
