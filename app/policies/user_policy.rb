class UserPolicy < ApplicationPolicy
  def index?   = can?("index")
  def show?    = can?("show")
  def new?     = can?("create")
  def create?  = can?("create")
  def edit?    = can?("update")
  def update?  = can?("update")
  def destroy? = can?("destroy") && record != user  # não pode excluir a si mesmo

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.all
  end

  private

  def resource_name = "users"
end
