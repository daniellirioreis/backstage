module Reports
  class FechamentoController < ApplicationController
    def index
      authorize :report, :fechamento?
      @basis = params[:basis].presence_in(%w[shifts attendance]) || "shifts"
      load_report_data
    end

    def print
      authorize :report, :fechamento?
      @basis = params[:basis].presence_in(%w[shifts attendance]) || "shifts"
      load_report_data
      render pdf:         "fechamento-#{@event.name.parameterize}-#{@basis}",
             template:    "reports/fechamento/print",
             layout:      "pdf",
             formats:     [:html],
             page_size:   "A4",
             orientation: "Landscape",
             margin:      { top: 10, bottom: 10, left: 10, right: 10 },
             disposition: "attachment"
    end

    private

    def load_report_data
      @event = current_event
      @basis == "attendance" ? load_by_attendance : load_by_shifts
    end

    # ── Opção 1: por escalas cadastradas ──────────────────────────
    def load_by_shifts
      shifts = Shift.joins(team: :sector)
                    .where(sectors: { event_id: @event.id })
                    .includes(:user, team: :sector)

      memberships    = event_memberships
      membership_map = memberships.index_by { |tm| [tm.team_id, tm.user_id] }

      rows = {}
      shifts.each do |shift|
        tm    = membership_map[[shift.team_id, shift.user_id]]
        fn    = tm&.event_function
        hours = hours_from_shift(shift)

        key = shift.user_id
        rows[key] ||= new_row(shift.user, fn)
        rows[key][:entries] << {
          label: format_shift_label(shift),
          hours: hours
        }
        rows[key][:total_hours] += hours
        rows[key][:total_value] += hours * (fn&.hourly_rate || 0)
      end

      @rows        = rows.values.sort_by { |r| r[:user].name }
      @grand_total = @rows.sum { |r| r[:total_value] }
    end

    # ── Opção 2: por check-in / check-out ─────────────────────────
    def load_by_attendance
      attendances = Attendance.where(event: @event)
                              .where.not(checked_out_at: nil)
                              .includes(:user, :team)

      memberships    = event_memberships
      membership_map = memberships.index_by(&:user_id)

      rows = {}
      attendances.each do |att|
        hours = (att.checked_out_at - att.checked_in_at) / 3600.0
        tm    = membership_map[att.user_id]
        fn    = tm&.event_function

        key = att.user_id
        rows[key] ||= new_row(att.user, fn)
        rows[key][:entries] << {
          date:         l(att.checked_in_date, format: :short),
          checked_in:   att.checked_in_at.strftime("%H:%M"),
          checked_out:  att.checked_out_at.strftime("%H:%M"),
          hours:        hours
        }
        rows[key][:total_hours] += hours
        rows[key][:total_value] += hours * (fn&.hourly_rate || 0)
      end

      # Colaboradores com check-in mas sem check-out
      pending = Attendance.where(event: @event, checked_out_at: nil)
                          .includes(:user)
      @pending_rows = pending.map do |att|
        tm = membership_map[att.user_id]
        { user: att.user, function_name: tm&.event_function&.name || "—",
          checked_in_at: att.checked_in_at }
      end.sort_by { |r| r[:user].name }

      @rows        = rows.values.sort_by { |r| r[:user].name }
      @grand_total = @rows.sum { |r| r[:total_value] }
    end

    def new_row(user, fn)
      {
        user:          user,
        function_name: fn&.name || "—",
        hourly_rate:   fn&.hourly_rate || 0,
        entries:       [],
        total_hours:   0.0,
        total_value:   0.0
      }
    end

    def event_memberships
      TeamMembership.joins(team: :sector)
                    .where(sectors: { event_id: @event.id })
                    .includes(:event_function)
    end

    def hours_from_shift(shift)
      s_min    = shift.start_time.hour * 60 + shift.start_time.min
      e_min    = shift.end_time.hour   * 60 + shift.end_time.min
      end_date = shift.end_date.presence || shift.date
      total_min = (end_date - shift.date).to_i * 1440 + e_min - s_min
      total_min += 1440 if total_min <= 0
      total_min.to_f / 60.0
    end

    def format_shift_label(shift)
      label = l(shift.date, format: :short)
      label += " → #{l(shift.end_date, format: :short)}" if shift.end_date && shift.end_date != shift.date
      label += " · #{shift.start_time.strftime('%H:%M')}–#{shift.end_time.strftime('%H:%M')}"
      label
    end
  end
end
