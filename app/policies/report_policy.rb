class ReportPolicy < ApplicationPolicy
  def fechamento? = can?("fechamento")

  private

  def resource_name = "reports"
end
