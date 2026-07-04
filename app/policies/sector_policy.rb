class SectorPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve = scope.all
  end

  # Estrutural: só no rascunho, bloqueado para todos quando encerrado
  def create?  = can?("create")  && !event_closed? && (user.admin? || event_draft?)
  def edit?    = can?("update")  && !event_closed? && (user.admin? || event_draft?)
  def update?  = can?("update")  && !event_closed? && (user.admin? || event_draft?)
  def destroy? = can?("destroy") && !event_closed? && (user.admin? || event_draft?)

  private

  def resource_name = "sectors"
end
