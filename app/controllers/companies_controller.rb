class CompaniesController < ApplicationController
  before_action :set_company, only: %i[show edit update destroy add_user update_user_role remove_user set_plan]

  def index
    authorize Company
    @companies = policy_scope(Company).includes(:plan, :company_users, :events).order(:name)

    if current_user.admin?
      @status_filter = params[:status].presence
      @companies = @companies.where(subscription_status: @status_filter) if @status_filter

      # Métricas
      all = Company.includes(:plan)
      @total          = all.count
      @total_active   = all.where(subscription_status: "active").count
      @total_overdue  = all.where(subscription_status: "overdue").count
      @total_inactive = all.where(subscription_status: %w[inactive pending cancelled]).count
      @mrr = all.where(subscription_status: "active")
                 .joins(:plan).sum("plans.price")
      @plans = Plan.order(:name)
    end
  end

  def show
    authorize @company
    scope = @company.company_users.includes(:user).joins(:user).order("users.name")
    if params[:q].present?
      scope = scope.where("users.name ILIKE ? OR users.email ILIKE ?", "%#{params[:q]}%", "%#{params[:q]}%")
    end
    @company_users = scope.paginate(page: params[:page], per_page: 10)
    @search_query  = params[:q].to_s
    @available_users = User.order(:name) - @company.users
    @plans = Plan.order(:name) if policy(@company).set_plan?
  end

  def new
    authorize Company
    @company = Company.new
    @plans = Plan.order(:name) if current_user.admin?
  end

  def create
    authorize Company
    @company = Company.new(company_params)
    if @company.save
      CompanyUser.create!(company: @company, user: current_user, role: "owner") unless current_user.admin?
      redirect_to @company, notice: t("notices.created", model: Company.model_name.human)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @company
  end

  def update
    authorize @company
    if @company.update(company_params)
      redirect_to @company, notice: t("notices.updated", model: Company.model_name.human)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @company
    @company.destroy
    redirect_to companies_path, notice: t("notices.destroyed", model: Company.model_name.human)
  end

  def add_user
    authorize @company, :add_user?
    user = User.find(params[:user_id])
    role = params[:role].presence_in(CompanyUser::ROLES) || "operator"

    cu = CompanyUser.find_or_initialize_by(company: @company, user: user)
    cu.role = role
    cu.save!
    redirect_to @company, notice: t("companies.user_added", name: user.name, role: cu.role_label)
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @company, alert: e.message
  end

  def update_user_role
    authorize @company, :update?
    cu = CompanyUser.find_by!(company: @company, user_id: params[:user_id])
    role = params[:role].presence_in(CompanyUser::ROLES) || cu.role
    cu.update!(role: role)
    redirect_to @company, notice: "Perfil de #{cu.user.name} atualizado para #{cu.role_label}."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @company, alert: e.message
  end

  def remove_user
    authorize @company, :update?
    cu = CompanyUser.find_by!(company: @company, user_id: params[:user_id])
    cu.destroy
    redirect_to @company, notice: t("companies.user_removed")
  end

  def set_plan
    authorize @company, :set_plan?
    plan_id = params.dig(:company, :plan_id).presence
    unless plan_id
      return redirect_to company_path(@company, tab: "plano"), alert: "Selecione um plano."
    end
    @company.update!(plan_id: plan_id)
    redirect_to company_path(@company, tab: "plano"), notice: "Plano atualizado com sucesso."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to company_path(@company, tab: "plano"), alert: e.message
  end

  private

  def set_company
    @company = Company.find(params[:id])
  end

  def company_params
    permitted = params.require(:company).permit(:name, :cnpj, :phone, :email, :address, :city, :state, :primary_color, :logo, :company_id, :plan_id)
    permitted[:plan_id] = nil if permitted.key?(:plan_id) && permitted[:plan_id].blank?
    permitted
  end
end
