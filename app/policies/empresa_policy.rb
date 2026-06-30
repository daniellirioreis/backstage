class EmpresaPolicy < ApplicationPolicy
  # Apenas admin pode listar/criar/destruir empresas
  def index?   = user.admin?
  def new?     = user.admin?
  def create?  = user.admin?
  def destroy? = user.admin?

  # Ver e editar: admin OU owner/manager da empresa
  def show?   = user.admin? || member_of_empresa?
  def edit?   = user.admin? || owner_or_manager?
  def update? = user.admin? || owner_or_manager?

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.joins(:empresa_users).where(empresa_users: { user_id: user.id })
      end
    end
  end

  private

  def member_of_empresa?
    record.is_a?(Empresa) && record.empresa_users.exists?(user: user)
  end

  def owner_or_manager?
    record.is_a?(Empresa) && record.empresa_users.exists?(user: user, role: %w[owner manager])
  end
end
