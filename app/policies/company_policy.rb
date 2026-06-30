class CompanyPolicy < ApplicationPolicy
  def index?   = user.admin?
  def new?     = user.admin?
  def create?  = user.admin?
  def destroy? = user.admin?

  def show?   = user.admin? || member?
  def edit?   = user.admin? || owner_or_manager?
  def update? = user.admin? || owner_or_manager?

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.joins(:company_users).where(company_users: { user_id: user.id })
      end
    end
  end

  private

  def member?
    record.is_a?(Company) && record.company_users.exists?(user: user)
  end

  def owner_or_manager?
    record.is_a?(Company) && record.company_users.exists?(user: user, role: %w[owner manager])
  end
end
