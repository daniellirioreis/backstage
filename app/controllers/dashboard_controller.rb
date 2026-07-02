class DashboardController < ApplicationController
  def index
    company_ids = if current_user.admin?
      Company.pluck(:id)
    else
      current_user.company_users.pluck(:company_id)
    end

    event_ids = Event.where(company_id: company_ids).pluck(:id)

    @total_sectors  = Sector.where(event_id: event_ids).count
    @total_teams    = Team.joins(:sector).where(sectors: { event_id: event_ids }).count
    @total_members  = TeamMembership.joins(team: :sector)
                                    .where(sectors: { event_id: event_ids })
                                    .select(:user_id).distinct.count
    @total_vehicles = Vehicle.count

    @events = Event.where(id: event_ids)
                   .includes(sectors: { teams: :team_memberships })
                   .order(start_date: :desc)
  end
end
