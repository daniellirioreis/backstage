class InvitationPolicy < ApplicationPolicy
  def index?  = user.present? && (user.admin? || can?("index"))
  def create? = user.present? && (user.admin? || can?("create"))

  private

  def resource_name = "invitations"
end
