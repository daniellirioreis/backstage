class EventImportPolicy < ApplicationPolicy
  def new?    = manager_or_owner?
  def create? = manager_or_owner?

  private

  def resource_name = "events"

  def manager_or_owner?
    return true if user&.admin?
    user&.company_users&.where(role: %w[owner manager])&.exists?
  end
end
