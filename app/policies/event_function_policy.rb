class EventFunctionPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve = scope.all
  end

  # Estrutural: só no rascunho
  def create?  = can?("create")  && (user.admin? || event_draft?)
  def edit?    = can?("update")  && (user.admin? || event_draft?)
  def update?  = can?("update")  && (user.admin? || event_draft?)
  def destroy? = can?("destroy") && (user.admin? || event_draft?)

  private

  def resource_name = "events"
end
