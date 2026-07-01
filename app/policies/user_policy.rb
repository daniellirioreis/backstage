class UserPolicy < ApplicationPolicy
  def index?   = can?("index")
  def show?    = can?("show")
  def new?     = can?("create")
  def create?  = can?("create")
  def edit?    = user == record || can?("update")
  def update?  = user == record || can?("update")
  def destroy?     = can?("destroy") && record != user
  def credential?  = user.present? && (user.admin? || user == record || can?("show"))
  def my_schedule? = user.present? && (user.admin? || user == record || can?("my_schedule"))

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user.admin?
      company_ids = user.company_users.pluck(:company_id)
      return scope.all if company_ids.empty?
      scope.joins(:company_users).where(company_users: { company_id: company_ids })
    end
  end

  private

  def resource_name = "users"
end
