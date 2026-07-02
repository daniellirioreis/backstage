class DashboardController < ApplicationController
  def index
    authorize :dashboard, :index?

    company_ids = if current_user.admin?
      Company.pluck(:id)
    else
      current_user.company_users.pluck(:company_id)
    end

    event_ids = Event.where(company_id: company_ids).pluck(:id)

    @total_events   = event_ids.size
    @active_events  = Event.where(id: event_ids, status: :active).count
    @total_sectors  = Sector.where(event_id: event_ids).count
    @total_teams    = Team.joins(:sector).where(sectors: { event_id: event_ids }).count
    @total_members  = TeamMembership.joins(team: :sector)
                                    .where(sectors: { event_id: event_ids })
                                    .select(:user_id).distinct.count
    @total_vehicles = Vehicle.count
    @total_users    = company_ids.any? ? User.joins(:company_users)
                                             .where(company_users: { company_id: company_ids })
                                             .distinct.count : 0

    @events_by_status = Event.where(id: event_ids).group(:status).count

    @events = Event.where(id: event_ids)
                   .includes(sectors: { teams: :team_memberships })
                   .order(start_date: :desc)

    # ── Custo por evento (turnos × taxa/hora da função) ───────────────────────
    all_shifts = Shift.joins(:sector)
                      .where(sectors: { event_id: event_ids })
                      .includes(:sector)

    memberships_map = TeamMembership.includes(:event_function)
                                    .where(team_id: all_shifts.map(&:team_id).compact.uniq)
                                    .each_with_object({}) { |m, h| h[[m.user_id, m.team_id]] = m }

    @event_costs = Hash.new(0.0)
    all_shifts.each do |shift|
      next unless shift.team_id
      rate = memberships_map[[shift.user_id, shift.team_id]]&.event_function&.hourly_rate.to_f
      next unless rate > 0

      s = shift.start_time.hour * 60 + shift.start_time.min
      e = shift.end_time.hour   * 60 + shift.end_time.min
      hours_per_day = (e > s ? e - s : 1440 - s + e) / 60.0
      days = shift.end_date.present? ? (shift.end_date - shift.date).to_i + 1 : 1
      @event_costs[shift.sector.event_id] += hours_per_day * days * rate
    end

    @total_cost = @event_costs.values.sum
  end
end
