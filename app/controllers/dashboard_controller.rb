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

    # ── Stats do evento atual ─────────────────────────────────────────────────
    if current_event
      @ev_sectors = Sector.where(event: current_event).count
      @ev_teams   = Team.joins(:sector).where(sectors: { event_id: current_event.id }).count
      @ev_members = TeamMembership.joins(team: :sector)
                                  .where(sectors: { event_id: current_event.id })
                                  .select(:user_id).distinct.count
      @ev_cost    = @event_costs[current_event.id] || 0.0

      if current_event.active?
        today = Date.today
        @ev_checkins_today  = Attendance.where(event: current_event, checked_in_date: today).count
        @ev_inside_now      = Attendance.where(event: current_event, checked_in_date: today, checked_out_at: nil).count
        @ev_checkouts_today = Attendance.where(event: current_event, checked_in_date: today).where.not(checked_out_at: nil).count
        @ev_expected_today  = Shift.joins(:sector)
                                   .where(sectors: { event_id: current_event.id })
                                   .where("shifts.date <= :d AND (shifts.end_date IS NULL OR shifts.end_date >= :d)", d: today)
                                   .select(:user_id).distinct.count
      elsif current_event.closed?
        @ev_total_checkins = Attendance.where(event: current_event).count
        @ev_present        = Attendance.where(event: current_event).select(:user_id).distinct.count
        paid               = Payment.where(event: current_event).sum(:amount)
        @ev_paid           = paid
      end
    end
  end
end
