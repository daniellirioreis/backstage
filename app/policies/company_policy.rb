class CompanyPolicy < ApplicationPolicy
  def index?   = can?("index")
  def new?     = can?("create")
  def create?  = can?("create")
  def destroy? = can?("destroy")

  def show?     = can?("show") || member?
  def edit?     = can?("update") || owner_or_manager?
  def update?   = can?("update") || owner_or_manager?
  def add_user? = user.present? && user.admin?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user.admin?
      return scope.joins(:company_users).where(company_users: { user_id: user.id }) if user.can?("companies", "index")
      scope.none
    end
  end

  private

  def resource_name = "companies"

  def member?
    record.is_a?(Company) && record.company_users.exists?(user: user)
  end

  def owner_or_manager?
    record.is_a?(Company) && record.company_users.exists?(user: user, role: %w[owner manager])
  end
end
