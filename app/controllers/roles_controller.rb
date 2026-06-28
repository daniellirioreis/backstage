class RolesController < ApplicationController
  before_action :set_role, only: %i[show edit update destroy]

  def index
    authorize Role
    @roles = policy_scope(Role).includes(:permissions).order(:name)
  end

  def show
    authorize @role
  end

  def new
    authorize Role
    @role = Role.new
  end

  def create
    authorize Role
    @role = Role.new(role_params)
    if @role.save
      sync_permissions(@role)
      redirect_to roles_path, notice: t("notices.created", model: Role.model_name.human)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @role
  end

  def update
    authorize @role
    if @role.update(role_params)
      sync_permissions(@role)
      redirect_to roles_path, notice: t("notices.updated", model: Role.model_name.human)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @role
    @role.destroy
    redirect_to roles_path, notice: t("notices.destroyed", model: Role.model_name.human)
  end

  private

  def set_role
    @role = Role.includes(:permissions).find(params[:id])
  end

  def role_params
    params.require(:role).permit(:name, :collaborator)
  end

  def sync_permissions(role)
    keys = (params.dig(:role, :permission_keys) || []).reject(&:blank?)

    desired = keys.map do |key|
      resource, action = key.split(":")
      { resource: resource, action: action }
    end

    # Remove permissões que foram desmarcadas
    role.permissions.each do |perm|
      unless desired.any? { |d| d[:resource] == perm.resource && d[:action] == perm.action }
        perm.destroy
      end
    end

    # Cria permissões novas
    desired.each do |d|
      role.permissions.find_or_create_by!(resource: d[:resource], action: d[:action])
    end
  end
end
