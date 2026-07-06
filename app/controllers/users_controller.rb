class UsersController < ApplicationController
  before_action :set_user, only: %i[show edit update destroy credential my_schedule]

  def index
    authorize User
    @roles     = Role.order(:name)
    @companies = if current_user.admin?
      Company.order(:name)
    else
      Company.joins(:company_users)
             .where(company_users: { user_id: current_user.id })
             .order(:name)
    end
    scope      = policy_scope(company_users_scope).includes(:role, :avatar_attachment, :companies)

    if params[:q].present?
      q      = params[:q].strip
      digits = q.gsub(/\D/, "")
      scope  = if digits.length >= 3
        scope.where("users.name ILIKE ? OR users.cpf LIKE ?", "%#{q}%", "%#{digits}%")
      else
        scope.where("users.name ILIKE ?", "%#{q}%")
      end
    end

    scope = scope.where(role_id: params[:role_id]) if params[:role_id].present?

    if params[:company_id].present?
      scope = scope.where(id: User.joins(:company_users).where(company_users: { company_id: params[:company_id] }).select(:id))
    end

    @users = scope.order("users.name").distinct.paginate(page: params[:page], per_page: 10)
    @total = @users.total_entries
  end

  def search
    authorize User, :index?
    q      = params[:q].to_s.strip
    digits = q.gsub(/\D/, "")

    base = company_users_scope

    scope = if q.present?
      if digits.present?
        base.where("users.name ILIKE ? OR users.cpf LIKE ?", "%#{q}%", "%#{digits}%")
      else
        base.where("users.name ILIKE ?", "%#{q}%")
      end
    else
      base
    end

    @users = scope.includes(:avatar_attachment).order("users.name").limit(100)

    render json: @users.map { |u|
      {
        id:         u.id,
        name:       u.name,
        cpf:        u.cpf.gsub(/(\d{3})(\d{3})(\d{3})(\d{2})/, '\1.\2.\3-\4'),
        avatar_url: u.avatar.attached? ? url_for(u.avatar) : nil,
        initials:   u.name.split.map(&:first).first(2).join.upcase
      }
    }
  end

  def show
    authorize @user
  end

  def credential
    authorize @user, :credential?
    event_id = params[:event_id].presence || current_event&.id
    @event   = event_id ? Event.find_by(id: event_id) : current_event
    @team = @user.teams.joins(:sector)
                 .where(sectors: { event_id: event_id })
                 .includes(:sector)
                 .first
    @badge_config = @event&.badge_config || BadgeConfig.defaults

    membership       = TeamMembership.includes(:event_function).find_by(team: @team, user: @user)
    @is_coordinator  = membership&.coordinator?
    @credential_code    = membership&.full_credential_code
    @credential_qr_code = membership&.credential_code
    @function_name      = membership&.event_function&.name

    respond_to do |format|
      format.html { render layout: "credential" }
      format.pdf do
        # Embed avatar as base64 so wkhtmltopdf can render it without HTTP access
        if @user.avatar.attached?
          blob = @user.avatar.blob
          @avatar_base64 = "data:#{blob.content_type};base64,#{Base64.strict_encode64(blob.download)}"
        end

        render pdf: "credencial-#{@user.name.parameterize}",
               template: "users/credential_pdf",
               layout: "credential_pdf",
               formats: [:html],
               page_width: "80mm", page_height: "123.5mm",
               margin: { top: 0, bottom: 0, left: 0, right: 0 },
               disposition: "attachment"
      end
    end
  end

  def my_schedule
    authorize @user, :my_schedule?

    @company_memberships = @user.company_users.eager_load(:company).order("companies.name")

    shifts = Shift.joins(sector: :event)
                  .where(user_id: @user.id)
                  .includes({ team: [:sector, :coordinator] }, sector: :event)
                  .order("events.start_date, shifts.date, shifts.start_time")

    @shifts_by_event = shifts.group_by { |s| s.sector.event }
                             .sort_by { |ev, _| [{ "active" => 0, "draft" => 1, "closed" => 2 }[ev.status] || 3, -ev.start_date.to_time.to_i] }
                             .to_h
  end

  def new
    authorize User
    @user = User.new
    @companies = companies_for_selector
  end

  def create
    authorize User
    @user = User.new(user_params)
    # Se nenhuma senha foi definida, gera uma aleatória
    if @user.password.blank?
      @user.password = @user.password_confirmation = SecureRandom.hex(12)
    end
    if @user.save
      # Empresa: usa a do usuário logado; se não tiver, usa a selecionada no form
      company = current_user.company_users.includes(:company).first&.company
      company ||= Company.find_by(id: params[:company_id]) if params[:company_id].present?
      CompanyUser.find_or_create_by!(user: @user, company: company) if company
      redirect_to users_path, notice: t("notices.created", model: User.model_name.human)
    else
      @companies = companies_for_selector
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @user
    @company_memberships = @user.company_users.eager_load(:company).order("companies.name")
  end

  def update
    authorize @user
    params_to_update = user_params
    if params_to_update[:password].blank?
      params_to_update = params_to_update.except(:password, :password_confirmation)
    end

    if @user.update(params_to_update)
      redirect_to users_path, notice: t("notices.updated", model: User.model_name.human)
    else
      @company_memberships = @user.company_users.eager_load(:company).order("companies.name")
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @user
    @user.destroy
    redirect_to users_path, notice: t("notices.destroyed", model: User.model_name.human)
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    permitted = [:name, :cpf, :phone, :email, :password, :password_confirmation, :avatar, :remove_avatar]
    permitted << :role_id if current_user.admin? || policy(User).create?
    params.require(:user).permit(permitted)
  end

  # Retorna empresas disponíveis para seleção — só quando o usuário logado não tem empresa
  def companies_for_selector
    return nil if current_user.company_users.exists?
    current_user.admin? ? Company.order(:name) : nil
  end
end
