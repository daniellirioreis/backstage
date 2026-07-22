class InvitationsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:accept, :confirm]
  skip_before_action :check_onboarding!,  only: [:accept, :confirm]
  skip_before_action :require_current_event!

  layout :invitation_layout

  before_action :find_invited_user, only: [:accept, :confirm]

  def index
    authorize :invitation, :index?
    scope = User.where.not(invitation_token: nil)
                .includes(:role, :companies)
                .order(created_at: :desc)

    unless current_user.admin?
      company_ids = current_user.companies.pluck(:id)
      scope = scope.joins(:company_users)
                   .where(company_users: { company_id: company_ids })
    end

    @invitations = scope
  end

  def new
    authorize :invitation, :create?
    @roles = Role.where(name: %w[colaborador coordenador gerente]).order(:name)
    if current_user.admin?
      @companies    = Company.order(:name)
      @user_company = nil
    else
      @user_company = current_user.companies.first
      @companies    = @user_company ? [@user_company] : []
    end
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
    if @invited_user.invitation_expired?
      return redirect_to new_user_session_path,
        alert: "Este convite expirou. Peça ao administrador que envie um novo convite."
    end
    @company     = @invited_user.companies.first
    @invited_by  = @invited_user.invited_by
    @company_role = @invited_user.company_users.find_by(company: @company)&.role
    @days_left   = @invited_user.invitation_sent_at.present? ?
      ((@invited_user.invitation_sent_at + User::INVITATION_EXPIRES_IN - Time.current) / 1.day).ceil : nil
  end

  def confirm
    return redirect_to root_path, alert: "Convite inválido." unless @invited_user
    return redirect_to new_user_session_path, notice: "Este convite já foi utilizado." if @invited_user.invitation_accepted_at?
    if @invited_user.invitation_expired?
      return redirect_to new_user_session_path,
        alert: "Este convite expirou. Peça ao administrador que envie um novo convite."
    end

    @invited_user.assign_attributes(
      name:                   params[:user][:name].to_s.strip,
      cpf:                    params[:user][:cpf].to_s.gsub(/\D/, ""),
      phone:                  params[:user][:phone].to_s.strip,
      password:               params[:user][:password],
      password_confirmation:  params[:user][:password_confirmation],
      invitation_accepted_at: Time.current,
      onboarding_completed_at: Time.current
    )

    if @invited_user.save
      sign_in @invited_user
      redirect_to root_path, notice: "Bem-vindo ao Backstage, #{@invited_user.name.split.first}!"
    else
      @company     = @invited_user.companies.first
      @invited_by  = @invited_user.invited_by
      @company_role = @invited_user.company_users.find_by(company: @company)&.role
      render :accept, status: :unprocessable_entity
    end
  end

  private

  def find_invited_user
    @invited_user = User.includes(:invited_by, company_users: :company)
                        .find_by(invitation_token: params[:token])
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
