class TeamPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve = scope.all
  end

  # Estrutural: só no rascunho
  def create?  = can?("create")  && (user.admin? || event_draft?)
  def edit?    = can?("update")  && (user.admin? || event_draft?)
  def update?  = can?("update")  && (user.admin? || event_draft?)
  def destroy? = can?("destroy") && (user.admin? || event_draft?)

  # Credenciais: só com evento ativo
  def credentials? = can?("show") && (user.admin? || event_active?)

  private

  def resource_name = "teams"
end
