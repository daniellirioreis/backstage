class UsersController < ApplicationController
  before_action :set_user, only: %i[show edit update destroy credential my_schedule]

  def index
    authorize User
    @roles = Role.order(:name)
    scope  = policy_scope(User).includes(:role, :avatar_attachment)

    if params[:q].present?
      q      = params[:q].strip
      digits = q.gsub(/\D/, "")
      scope  = if digits.length >= 3
        scope.where("name ILIKE ? OR cpf LIKE ?", "%#{q}%", "%#{digits}%")
      else
        scope.where("name ILIKE ?", "%#{q}%")
      end
    end

    scope = scope.where(role_id: params[:role_id]) if params[:role_id].present?

    @users = scope.order(:name)
    @total = @users.size
  end

  def search
    authorize User, :index?
    q      = params[:q].to_s.strip
    digits = q.gsub(/\D/, "")

    scope = if q.present?
      if digits.present?
        User.where("name ILIKE ? OR cpf LIKE ?", "%#{q}%", "%#{digits}%")
      else
        User.where("name ILIKE ?", "%#{q}%")
      end
    else
      User.all
    end

    @users = scope.includes(:avatar_attachment).order(:name).limit(100)

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
    @is_coordinator = @team&.coordinator_id == @user.id
    @badge_config   = @event&.badge_config || BadgeConfig.defaults

    if @is_coordinator
      @credential_code = @team&.coordinator_full_credential_code
    else
      membership = TeamMembership.find_by(team: @team, user: @user)
      @credential_code = membership&.full_credential_code
    end

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

    shifts = Shift.joins(sector: :event)
                  .where(user_id: @user.id)
                  .includes({ team: [:sector, :coordinator] }, sector: :event)
                  .order("events.start_date, shifts.date, shifts.start_time")

    @shifts_by_event = shifts.group_by { |s| s.sector.event }
                             .sort_by { |ev, _| ev.start_date }
                             .to_h
  end

  def new
    authorize User
    @user = User.new
  end

  def create
    authorize User
    @user = User.new(user_params)
    if @user.save
      redirect_to users_path, notice: t("notices.created", model: User.model_name.human)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @user
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
    params.require(:user).permit(:name, :cpf, :phone, :email, :role_id, :password, :password_confirmation, :avatar, :remove_avatar)
  end
end
