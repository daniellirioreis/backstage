class EventPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user.admin?
      company_ids = user.company_users.pluck(:company_id)
      scope.where(company_id: company_ids)
    end
  end

  # Editar/excluir evento só no rascunho
  def edit?    = can?("update")  && (user.admin? || record.draft?)
  def update?  = can?("update")  && (user.admin? || record.draft?)
  def destroy? = can?("destroy") && (user.admin? || record.draft?)

  def print? = can?("print")

  private

  def resource_name = "events"
end
