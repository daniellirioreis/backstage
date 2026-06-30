class EmpresasController < ApplicationController
  before_action :set_empresa, only: %i[show edit update destroy]

  def index
    authorize Empresa
    @empresas = policy_scope(Empresa).order(:name)
  end

  def show
    authorize @empresa
    @empresa_users = @empresa.empresa_users.includes(:user).order("users.name")
    @available_users = User.order(:name) - @empresa.users
  end

  def new
    authorize Empresa
    @empresa = Empresa.new
  end

  def create
    authorize Empresa
    @empresa = Empresa.new(empresa_params)
    if @empresa.save
      # Cria o criador como owner automaticamente
      EmpresaUser.create!(empresa: @empresa, user: current_user, role: "owner") unless current_user.admin?
      redirect_to @empresa, notice: "Empresa criada com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @empresa
  end

  def update
    authorize @empresa
    if @empresa.update(empresa_params)
      redirect_to @empresa, notice: "Empresa atualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @empresa
    @empresa.destroy
    redirect_to empresas_path, notice: "Empresa removida."
  end

  def add_user
    @empresa = Empresa.find(params[:id])
    authorize @empresa, :update?
    user = User.find(params[:user_id])
    role = params[:role].presence_in(EmpresaUser::ROLES) || "operator"

    eu = EmpresaUser.find_or_initialize_by(empresa: @empresa, user: user)
    eu.role = role
    eu.save!
    redirect_to @empresa, notice: "#{user.name} adicionado como #{eu.role_label}."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @empresa, alert: e.message
  end

  def remove_user
    @empresa = Empresa.find(params[:id])
    authorize @empresa, :update?
    eu = EmpresaUser.find_by!(empresa: @empresa, user_id: params[:user_id])
    eu.destroy
    redirect_to @empresa, notice: "Usuário removido da empresa."
  end

  private

  def set_empresa
    @empresa = Empresa.find(params[:id])
  end

  def empresa_params
    params.require(:empresa).permit(:name, :cnpj, :phone, :email, :address, :city, :state, :primary_color, :logo)
  end
end
