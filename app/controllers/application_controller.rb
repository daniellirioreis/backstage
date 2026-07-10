class ApplicationController < ActionController::Base
  include Pundit::Authorization

  before_action :authenticate_user!
  before_action :check_onboarding!
  before_action :require_current_event!
  before_action :check_company_plan!
  before_action :configure_permitted_parameters, if: :devise_controller?

  layout :resolve_layout

  helper_method :current_event
  helper_method :company_users_scope

  rescue_from Pundit::NotAuthorizedError, with: ->(e) { user_not_authorized(e) }

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
      Event.where(status: %w[active draft closed]).order(start_date: :desc)
    else
      company_ids = current_user.company_users.pluck(:company_id)
      Event.where(company_id: company_ids).where(status: %w[active draft closed]).order(start_date: :desc)
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
      current_user&.coordinator? ||       # coordenadores navegam pelo painel da equipe
      controller_name.in?(%w[
        event_session
        dashboard
        events
        setup
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
      ]) ||
      (controller_name == "users" && action_name == "my_schedule")
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
    if resource.coordinator?
      team = Team.find_by(coordinator_id: resource.id)
      return panel_team_path(team) if team
    end
    super
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_in, keys: [:login])
  end

  def user_not_authorized(exception = nil)
    message = not_authorized_message(exception)
    if request.format.json?
      render json: { status: :error, message: message }, status: :forbidden
    else
      flash[:alert] = message
      # Evita loop infinito: se já estamos no root e não temos permissão,
      # redirecionar para root novamente criaria um loop. Vai para o login.
      fallback = request.path == root_path ? new_user_session_path : root_path
      safe_back = request.referer.present? &&
                  !request.referer.include?(new_user_session_path) &&
                  request.referer != request.url &&
                  URI.parse(request.referer).path != root_path
      safe_back ? redirect_back(fallback_location: fallback) : redirect_to(fallback)
    end
  end

  def not_authorized_message(exception)
    query  = exception&.query&.to_s&.delete_suffix("?")
    record = exception&.record

    event_status = current_event&.status

    # Mensagens específicas por contexto
    case query
    when "create", "update", "edit", "destroy"
      # record pode ser instância OU classe (quando authorize recebe a classe diretamente)
      record_class = record.is_a?(Class) ? record : record.class
      case record_class
      when ->(c) { c <= Shift }
        return "Escalas só podem ser alteradas quando o evento está em Rascunho."
      when ->(c) { c <= Sector }
        return "Setores só podem ser alterados quando o evento está em Rascunho."
      when ->(c) { c <= Team }
        return "Equipes só podem ser alteradas quando o evento está em Rascunho."
      when ->(c) { c <= EventFunction }
        return "Funções do evento só podem ser alteradas quando o evento está em Rascunho."
      else
        return "Edição de eventos só é permitida quando o status é Rascunho." if event_status&.in?(%w[active closed])
      end
    when "scan", "checkout"
      return "Check-in e Check-out só estão disponíveis com o evento Ativo." \
             " Status atual: #{t("event_statuses.#{event_status}")}."
    when "credentials"
      return "Credenciais só estão disponíveis com o evento Ativo." \
             " Status atual: #{t("event_statuses.#{event_status}")}."
    when "closing"
      return "O Fechamento só está disponível após o evento ser Encerrado." \
             " Status atual: #{t("event_statuses.#{event_status}")}."
    end

    t("errors.not_authorized")
  end
end
