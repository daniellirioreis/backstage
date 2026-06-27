class EventSessionController < ApplicationController
  skip_before_action :require_current_event!

  def select_event
    @events = Event.order(start_date: :desc)
    redirect_to new_event_path, notice: "Crie um evento para começar." if @events.empty?
  end

  def set_event
    event = Event.find(params[:event_id])
    session[:current_event_id] = event.id
    redirect_to root_path, notice: "Trabalhando no evento: #{event.name}"
  end

  def clear_event
    session.delete(:current_event_id)
    redirect_to select_event_path
  end
end
