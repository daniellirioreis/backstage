class ApplicationController < ActionController::Base
  include Pundit::Authorization

  before_action :authenticate_user!
  before_action :require_current_event!

  layout :resolve_layout

  helper_method :current_event
  helper_method :company_users_scope

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def pundit_user
    current_user
  end

  def current_event
    return nil unless session[:current_event_id]
    @current_event ||= Event.find_by(id: session[:current_event_id])
  end

  # Returns a User scope filtered to the current event's company.
  # Admins and events without a company see all users.
  def company_users_scope
    return User.all if current_user&.admin?
    company = current_event&.company
    return User.all unless company
    User.joins(:company_users).where(company_users: { company_id: company.id })
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
      current_user&.role&.collaborator? ||
      controller_name == "event_session" ||
      controller_name == "events" ||
      controller_name == "users" ||
      controller_name == "roles" ||
      controller_name == "companies" ||
      controller_name == "vehicles"
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
      safe_back = request.referer.present? &&
                  !request.referer.include?(new_user_session_path) &&
                  request.referer != request.url
      safe_back ? redirect_back(fallback_location: root_path) : redirect_to(root_path)
    end
  end
end
