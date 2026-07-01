class ReportPolicy < ApplicationPolicy
  def closing? = can?("closing")

  private

  def resource_name = "reports"
end
