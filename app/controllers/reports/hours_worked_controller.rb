module Reports
  class HoursWorkedController < ApplicationController
    def index
      return redirect_to(select_event_path, alert: "Selecione um evento para continuar.") unless current_event
      authorize :report, :hours_worked_report?

      @event   = current_event
      @sectors = Sector.where(event: @event).order(:name)
      @sector  = @sectors.find_by(id: params[:sector_id])

      load_data
    end

    private

    def load_data
      # Horas escaladas por usuário
      shifts = Shift.joins(team: :sector)
                    .where(sectors: { event_id: @event.id })
                    .then { |q| @sector ? q.where(sectors: { id: @sector.id }) : q }
                    .includes(:user, team: :sector)

      scheduled_hours = Hash.new(0.0)
      sector_by_user  = {}
      team_by_user    = {}
      shifts.each do |s|
        hours = hours_from_shift(s)
        scheduled_hours[s.user_id] += hours
        sector_by_user[s.user_id] ||= s.team&.sector&.name
        team_by_user[s.user_id]   ||= s.team&.name
      end

      # Horas reais por usuário (apenas com checkout)
      attendances = Attendance.where(event: @event)
                              .where.not(checked_out_at: nil)
                              .then { |q| @sector ? q.joins(:team).where(teams: { sector_id: @sector.id }) : q }
                              .includes(:user)

      actual_hours    = Hash.new(0.0)
      entries_by_user = Hash.new { |h, k| h[k] = [] }
      attendances.each do |a|
        h = (a.checked_out_at - a.checked_in_at) / 3600.0
        actual_hours[a.user_id] += h
        entries_by_user[a.user_id] << {
          date:        a.checked_in_date,
          checked_in:  a.checked_in_at.strftime("%H:%M"),
          checked_out: a.checked_out_at.strftime("%H:%M"),
          hours:       h
        }
        sector_by_user[a.user_id] ||= a.team&.sector&.name
        team_by_user[a.user_id]   ||= a.team&.name
      end

      # Check-ins sem checkout (em atividade)
      pending_ids = Attendance.where(event: @event, checked_out_at: nil)
                              .then { |q| @sector ? q.joins(:team).where(teams: { sector_id: @sector.id }) : q }
                              .pluck(:user_id).to_set

      all_user_ids = (scheduled_hours.keys + actual_hours.keys).uniq
      users = User.where(id: all_user_ids).index_by(&:id)

      @rows = all_user_ids.map do |uid|
        sched  = scheduled_hours[uid]
        actual = actual_hours[uid]
        diff   = actual - sched

        {
          user:              users[uid],
          sector:            sector_by_user[uid],
          team:              team_by_user[uid],
          scheduled_hours:   sched,
          actual_hours:      actual,
          diff_hours:        diff,
          pending_checkout:  pending_ids.include?(uid),
          entries:           entries_by_user[uid].sort_by { |e| e[:date] }
        }
      end.sort_by { |r| r[:user]&.name.to_s }

      @total_scheduled = @rows.sum { |r| r[:scheduled_hours] }
      @total_actual    = @rows.sum { |r| r[:actual_hours] }
    end

    def hours_from_shift(shift)
      s_min     = shift.start_time.hour * 60 + shift.start_time.min
      e_min     = shift.end_time.hour   * 60 + shift.end_time.min
      end_date  = shift.end_date.presence || shift.date
      total_min = (end_date - shift.date).to_i * 1440 + e_min - s_min
      total_min += 1440 if total_min <= 0
      total_min.to_f / 60.0
    end
  end
end
