class EventFunctionPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve = scope.all
  end

  # Catálogo global (/event_functions) — recurso "event_functions"
  # Funções de evento (/events/:id/event_functions) — recurso "events" + evento em rascunho
  def index?   = catalog? ? can_catalog?("index")   : can_event?("index")
  def new?     = can_catalog?("create")
  def create?  = catalog? ? can_catalog?("create")  : can_event?("create")
  def edit?    = catalog? ? can_catalog?("update")  : can_event?("update")
  def update?  = catalog? ? can_catalog?("update")  : can_event?("update")
  def destroy? = catalog? ? can_catalog?("destroy") : can_event?("destroy")

  private

  # record é uma instância com event_id nil → catálogo
  # record é uma instância com event_id → função de evento
  def catalog?
    record.is_a?(Class) || record.event_id.nil?
  end

  # Permissão para o catálogo global (recurso "event_functions")
  def can_catalog?(action)
    user.present? && (user.admin? || user.can?("event_functions", action))
  end

  # Permissão para funções de um evento específico (recurso "events", requer rascunho)
  def can_event?(action)
    user.present? &&
      (user.admin? || user.can?("events", action)) &&
      (user.admin? || event_draft?)
  end

  def resource_name = "event_functions"
end
