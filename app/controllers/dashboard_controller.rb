class DashboardController < ApplicationController
  def index
    @total_users    = User.count
    @active_events  = Event.where(status: "active").count
    @shifts_today   = Shift.where(date: Date.today).count
    @total_vehicles = Vehicle.count

    @upcoming_shifts = Shift.includes(:user, sector: { team: :event })
                            .where("date >= ?", Date.today)
                            .order(:date, :start_time)
                            .limit(8)

    @recent_events = Event.order(created_at: :desc).limit(5)
  end
end
