class ShiftPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve = scope.all
  end

  def timeline? = can?("timeline")
  def print?    = can?("index")

  private

  def resource_name = "shifts"
end
