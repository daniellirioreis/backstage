class DashboardPolicy < ApplicationPolicy
  # Qualquer usuário autenticado pode ver o dashboard — colaboradores são
  # redirecionados para sua escala pelo controller, mas não ficam bloqueados.
  def index? = user.present?

  private

  def resource_name = "dashboard"
end
