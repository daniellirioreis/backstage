class AttendancePolicy < ApplicationPolicy
  def index?   = can?("index")
  def scan?    = user.present? && (user.admin? || can?("scan"))
  def destroy? = user.present? && (user.admin? || can?("destroy"))

  private

  def resource_name = "attendances"
end
