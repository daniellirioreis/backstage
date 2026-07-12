class EventFunctionsController < ApplicationController
  before_action :set_event
  before_action :set_event_function, only: %i[update destroy]

  def index
    authorize EventFunction
    @event_functions = @event.event_functions.order(:name)
  end

  def create
    authorize EventFunction

    name        = params.dig(:event_function, :name)&.strip
    hourly_rate = params.dig(:event_function, :hourly_rate)

    if name.blank? || hourly_rate.blank?
      redirect_to event_event_functions_path(@event), alert: "Informe nome e valor da função."
      return
    end

    ef = @event.event_functions.build(name: name, hourly_rate: hourly_rate)
    if ef.save
      redirect_to event_event_functions_path(@event), notice: "Função \"#{ef.name}\" criada."
    else
      redirect_to event_event_functions_path(@event), alert: ef.errors.full_messages.to_sentence
    end
  end

  def update
    authorize @event_function
    if @event_function.update(event_function_params)
      redirect_to event_event_functions_path(@event), notice: "Função atualizada."
    else
      redirect_to event_event_functions_path(@event), alert: @event_function.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize @event_function
    @event_function.destroy
    redirect_to event_event_functions_path(@event), notice: "Função removida."
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def set_event_function
    @event_function = @event.event_functions.find(params[:id])
  end

  def event_function_params
    params.require(:event_function).permit(:name, :hourly_rate)
  end
end
