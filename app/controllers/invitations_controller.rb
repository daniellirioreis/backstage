class InvitationsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:accept, :confirm]
  skip_before_action :check_onboarding!,  only: [:accept, :confirm]
  skip_before_action :require_current_event!

  layout :invitation_layout

  before_action :find_invited_user, only: [:accept, :confirm]

  def index
    authorize :invitation, :index?
    @invitations = User.where.not(invitation_token: nil)
                       .includes(:role, :companies)
                       .order(created_at: :desc)
  end

  def new
    authorize :invitation, :create?
    @roles     = Role.order(:name)
    @companies = Company.order(:name)
  end

  def create
    authorize :invitation, :create?
    role    = Role.find_by(id: params[:role_id])
    company = Company.find_by(id: params[:company_id]) if params[:company_id].present?

    # Verifica limite de colaboradores do plano
    if company && !company.can_add_member?
      @roles     = Role.order(:name)
      @companies = Company.order(:name)
      flash.now[:alert] = "Limite de colaboradores atingido para o plano #{company.plan.name} (#{company.members_limit} colaboradores). Entre em contato para upgrade."
      render :new, status: :unprocessable_entity
      return
    end

    @invited_user = User.new(
      name:                      params[:name].to_s.strip,
      email:                     params[:email].to_s.strip,
      role:                      role,
      password:                  SecureRandom.hex(16),
      invited_by_id:             current_user.id,
      skip_required_validations: true
    )

    if @invited_user.save
      token = @invited_user.generate_invitation_token!
      company_role = company_role_from(role)
      company&.company_users&.create(user: @invited_user, role: company_role)
      @invite_url = accept_invitation_url(token: token)
    else
      @roles     = Role.order(:name)
      @companies = Company.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def accept
    return redirect_to root_path, alert: "Convite inválido ou não encontrado." unless @invited_user
    return redirect_to new_user_session_path, notice: "Este convite já foi utilizado. Faça login." if @invited_user.invitation_accepted_at?
    @company = @invited_user.companies.first
  end

  def confirm
    return redirect_to root_path, alert: "Convite inválido." unless @invited_user
    return redirect_to new_user_session_path, notice: "Este convite já foi utilizado." if @invited_user.invitation_accepted_at?

    @invited_user.assign_attributes(
      name:                  params[:user][:name].to_s.strip,
      cpf:                   params[:user][:cpf].to_s.gsub(/\D/, ""),
      phone:                 params[:user][:phone].to_s.strip,
      password:              params[:user][:password],
      password_confirmation: params[:user][:password_confirmation],
      invitation_accepted_at: Time.current
    )

    if @invited_user.save
      sign_in @invited_user
      redirect_to onboarding_empresa_path
    else
      render :accept, status: :unprocessable_entity
    end
  end

  private

  def find_invited_user
    @invited_user = User.find_by(invitation_token: params[:token])
  end

  # Mapeia o Role do sistema para o papel hierárquico na empresa
  def company_role_from(role)
    case role&.name
    when "admin", "gerente" then "manager"
    when "coordenador"      then "operator"
    else                         "collaborator"
    end
  end

  def invitation_layout
    action_name.in?(%w[accept confirm]) ? "onboarding" : "application"
  end
end
