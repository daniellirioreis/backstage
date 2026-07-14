class EventPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user.admin?
      company_ids = user.company_users.pluck(:company_id)
      scope.where(company_id: company_ids)
    end
  end

  # Criação de evento: apenas owner e manager
  def new?    = can?("create") && manager_or_owner?
  def create? = can?("create") && manager_or_owner?

  # Editar/excluir evento: bloqueado para todos quando encerrado
  def edit?    = can?("update")  && !record.closed? && (user.admin? || record.draft?)
  def update?  = can?("update")  && !record.closed? && (user.admin? || record.draft?)
  def destroy? = can?("destroy") && !record.closed? && (user.admin? || record.draft?)

  # Transições de status: independente do status atual
  def transition? = can?("update")
  def revert?     = can?("update")

  def print?        = can?("print")
  def budget?       = can?("print")
  def folha_escala? = can?("print")
  def manual_entry? = can?("print")
  def credentials?  = can?("print")

  private

  def resource_name = "events"

  def manager_or_owner?
    return true if user.admin?
    user.company_users.where(role: %w[owner manager]).exists?
  end
end
