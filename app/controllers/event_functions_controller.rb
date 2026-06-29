class EventFunctionsController < ApplicationController
  before_action :set_event
  before_action :set_event_function, only: %i[edit update destroy]

  def create
    authorize EventFunction
    raw = params[:functions]

    if raw.blank?
      redirect_to edit_event_path(@event, anchor: "funcoes"), alert: "Informe ao menos uma função com nome e valor."
      return
    end

    # permit! libera os params aninhados indexados (functions[0][name], etc.)
    rows  = raw.permit!.to_h.values
    valid = rows.select { |r| r["name"].present? && r["hourly_rate"].present? }

    if valid.empty?
      redirect_to edit_event_path(@event, anchor: "funcoes"), alert: "Informe ao menos uma função com nome e valor."
      return
    end

    created = 0
    errors  = []
    valid.each do |row|
      ef = @event.event_functions.build(name: row["name"], hourly_rate: row["hourly_rate"])
      if ef.save
        created += 1
      else
        errors << "#{row["name"]}: #{ef.errors.full_messages.to_sentence}"
      end
    end

    msg = "#{created} função(ões) criada(s)."
    msg += " Erros: #{errors.join(' | ')}" if errors.any?
    redirect_to edit_event_path(@event, anchor: "funcoes"), notice: msg
  end

  def update
    authorize @event_function
    if @event_function.update(event_function_params)
      redirect_to edit_event_path(@event, anchor: "funcoes"), notice: "Função atualizada."
    else
      redirect_to edit_event_path(@event, anchor: "funcoes"), alert: @event_function.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize @event_function
    @event_function.destroy
    redirect_to edit_event_path(@event, anchor: "funcoes"), notice: "Função removida."
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
