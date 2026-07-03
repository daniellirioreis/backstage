class ShiftPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve = scope.all
  end

  # Escalas: só no rascunho ou ativo
  def create?  = can?("create")  && (user.admin? || event_draft? || event_active?)
  def edit?    = can?("update")  && (user.admin? || event_draft? || event_active?)
  def update?  = can?("update")  && (user.admin? || event_draft? || event_active?)
  def destroy? = can?("destroy") && (user.admin? || event_draft? || event_active?)

  def timeline? = can?("timeline")
  def print?    = can?("print")

  private

  def resource_name = "shifts"
end
