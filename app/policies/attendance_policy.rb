class AttendancePolicy < ApplicationPolicy
  def index?    = can?("index")

  # Check-in/out: só com evento ativo
  def scan?     = user.present? && (user.admin? || (can?("scan")     && event_active?))
  def create?   = user.present? && (user.admin? || (can?("scan")     && event_active?))
  def checkout? = user.present? && (user.admin? || (can?("checkout") && event_active?))
  def destroy?  = user.present? && (user.admin? || can?("destroy"))

  private

  def resource_name = "attendances"
end
