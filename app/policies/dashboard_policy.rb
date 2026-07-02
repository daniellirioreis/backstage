class DashboardPolicy < ApplicationPolicy
  def index? = user.present? && (user.admin? || can?("index"))

  private

  def resource_name = "dashboard"
end
