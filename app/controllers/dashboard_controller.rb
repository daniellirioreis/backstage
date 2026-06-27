class DashboardController < ApplicationController
  def index
    event = current_event

    @total_sectors  = event.sectors.count
    @total_teams    = Team.joins(:sector).where(sectors: { event_id: event.id }).count
    @total_members  = TeamMembership.joins(team: :sector).where(sectors: { event_id: event.id }).select(:user_id).distinct.count
    @total_vehicles = Vehicle.count

    @sectors = event.sectors.includes(teams: :users).order(:name)
  end
end
