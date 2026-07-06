class RolePolicy < ApplicationPolicy
  def index?   = user.admin? || can?("index")
  def show?    = user.admin? || can?("show")
  def new?     = user.admin? || can?("create")
  def create?  = user.admin? || can?("create")
  def edit?    = user.admin? || can?("update")
  def update?  = user.admin? || can?("update")
  def destroy? = user.admin? || can?("destroy")

  class Scope < ApplicationPolicy::Scope
    def resolve = (user.admin? || user.role&.permissions&.exists?(resource: "roles")) ? scope.all : scope.none
  end
end
