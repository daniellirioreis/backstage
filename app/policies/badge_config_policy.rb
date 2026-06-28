class BadgeConfigPolicy < ApplicationPolicy
  def edit?   = user.present? && (user.admin? || user.can?("badge_configs", "update"))
  def update? = edit?
end
