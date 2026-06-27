class RolePolicy < ApplicationPolicy
  # Somente admin pode gerenciar perfis
  def index?   = user.admin?
  def show?    = user.admin?
  def new?     = user.admin?
  def create?  = user.admin?
  def edit?    = user.admin?
  def update?  = user.admin?
  def destroy? = user.admin?

  class Scope < ApplicationPolicy::Scope
    def resolve = user.admin? ? scope.all : scope.none
  end
end
