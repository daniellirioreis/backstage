class ReportPolicy < ApplicationPolicy
  # Fechamento: só com evento encerrado
  def closing? = can?("closing") && (user.admin? || event_closed?)

  private

  def resource_name = "reports"
end
