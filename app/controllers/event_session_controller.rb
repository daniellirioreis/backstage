class EventSessionController < ApplicationController
  skip_before_action :require_current_event!

  def select_event
    @events = if current_user.admin?
      Event.includes(:company).order(start_date: :desc)
    else
      company_ids = current_user.company_users.pluck(:company_id)
      Event.includes(:company).where(company_id: company_ids).order(start_date: :desc)
    end

    if @events.empty?
      if policy(Event).new?
        redirect_to new_event_path, notice: "Crie um evento para começar."
      elsif current_user.role&.collaborator?
        redirect_to my_schedule_user_path(current_user), alert: t("errors.no_events_available")
      else
        redirect_to root_path, alert: t("errors.no_events_available")
      end
      return
    end

    if params[:modal] == "1"
      @return_to = params[:return_to].presence || root_path
      render "select_event_modal", layout: "application"
    end
  end

  def set_event
    event = Event.find(params[:event_id])
    session[:current_event_id] = event.id
    return_to = params[:return_to].presence || root_path
    redirect_to return_to, notice: "Trabalhando no evento: #{event.name}"
  end

  def clear_event
    session.delete(:current_event_id)
    redirect_to select_event_path(modal: 1, return_to: request.referer.presence || root_path)
  end
end
