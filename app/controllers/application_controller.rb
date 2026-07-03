class ApplicationController < ActionController::Base
  include Pundit::Authorization

  before_action :authenticate_user!
  before_action :check_onboarding!
  before_action :require_current_event!
  before_action :check_company_plan!

  layout :resolve_layout

  helper_method :current_event
  helper_method :company_users_scope

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  UserContext = Struct.new(:user, :event)

  def pundit_user
    UserContext.new(current_user, current_event)
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

    available = if current_user.admin?
      Event.order(start_date: :desc)
    else
      company_ids = current_user.company_users.pluck(:company_id)
      Event.where(company_id: company_ids).order(start_date: :desc)
    end

    if available.empty?
      redirect_to new_event_path, alert: "Crie um evento para começar." and return
    end

    # Auto-seleciona se só há um evento disponível
    if available.count == 1 && current_event.nil?
      @current_event = available.first
      session[:current_event_id] = @current_event.id
      return
    end

    unless current_event
      @return_to = request.path
      @events = available.includes(:company)
      render "event_session/select_event_modal", layout: "application"
      return
    end
  end

  def resolve_layout
    params[:modal] == "1" ? "modal" : "application"
  end

  def skip_event_check?
    devise_controller? ||
      current_user&.role&.collaborator? ||
      controller_name.in?(%w[
        event_session
        dashboard
        events
        users
        roles
        plans
        companies
        vehicles
        invitations
        onboarding
      ])
  end

  def check_company_plan!
    return unless user_signed_in?
    return if current_user.admin?
    return if skip_plan_check?

    # Prioriza a empresa do evento atual; cai no primeiro vínculo do usuário
    company = current_event&.company
    company ||= current_user.company_users.includes(:company).first&.company

    # Sem empresa ainda → onboarding cuida disso
    return unless company

    return if company.plan.present?

    redirect_to root_path, alert: "Sua empresa não possui um plano ativo. Entre em contato com o administrador para contratar um plano."
  end

  def skip_plan_check?
    devise_controller? ||
      controller_name.in?(%w[
        dashboard
        event_session
        onboarding
        companies
        plans
        invitations
      ])
  end

  def check_onboarding!
    return unless user_signed_in?
    return if current_user.onboarding_complete?
    return if current_user.pending_invitation? # ainda não aceitou o convite
    return if controller_name.in?(%w[onboarding invitations])
    return if devise_controller?
    redirect_to onboarding_empresa_path
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
