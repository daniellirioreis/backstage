class EventPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve = scope.all
  end

  def print? = can?("print")

  private

  def resource_name = "events"
end
