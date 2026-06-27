class VehiclePolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve = scope.all
  end

  private

  def resource_name = "vehicles"
end
