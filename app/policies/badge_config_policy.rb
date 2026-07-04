class BadgeConfigPolicy < ApplicationPolicy
  # Bloqueado quando o evento está encerrado
  def edit?   = !record.event.closed? && user.present? && (user.admin? || user.can?("badge_configs", "update"))
  def update? = edit?
end
