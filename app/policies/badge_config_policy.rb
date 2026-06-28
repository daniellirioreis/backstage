class BadgeConfigPolicy < ApplicationPolicy
  def edit?   = user.present? && (user.admin? || user.can?("events", "update"))
  def update? = edit?
end
