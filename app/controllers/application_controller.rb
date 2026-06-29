class ApplicationController < ActionController::Base
  include Pundit::Authorization

  before_action :authenticate_user!
  before_action :require_current_event!

  layout :resolve_layout

  helper_method :current_event

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def pundit_user
    current_user
  end

  def current_event
    return nil unless session[:current_event_id]
    @current_event ||= Event.find_by(id: session[:current_event_id])
  end

  def require_current_event!
    return unless user_signed_in?
    return if skip_event_check?

    if !Event.exists?
      redirect_to new_event_path, alert: "Crie um evento para começar." and return
    end

    unless current_event
      redirect_to select_event_path, alert: "Selecione um evento para continuar."
    end
  end

  def resolve_layout
    params[:modal] == "1" ? "modal" : "application"
  end

  def skip_event_check?
    devise_controller? ||
      controller_name == "event_session" ||
      controller_name == "events" ||
      (controller_name == "users" && action_name.in?(%w[my_schedule credential]))
  end

  def after_sign_in_path_for(resource)
    return super if resource.admin?
    return my_schedule_user_path(resource) if resource.role&.collaborator?
    super
  end

  def user_not_authorized
    if request.format.json?
      render json: { status: :error, message: t("errors.not_authorized") }, status: :forbidden
    else
      flash[:alert] = t("errors.not_authorized")
      redirect_back(fallback_location: root_path)
    end
  end
end
