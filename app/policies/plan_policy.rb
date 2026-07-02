class PlanPolicy < ApplicationPolicy
  def index?   = user.present? && user.admin?
  def show?    = user.present? && user.admin?
  def new?     = user.present? && user.admin?
  def create?  = user.present? && user.admin?
  def edit?    = user.present? && user.admin?
  def update?  = user.present? && user.admin?
  def destroy? = user.present? && user.admin?

  private

  def resource_name = "plans"
end
