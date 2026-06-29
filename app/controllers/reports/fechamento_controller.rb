module Reports
  class FechamentoController < ApplicationController
    def index
      authorize :report, :fechamento?
      load_report_data
    end

    def print
      authorize :report, :fechamento?
      load_report_data
      render pdf:      "fechamento-#{@event.name.parameterize}",
             template: "reports/fechamento/print",
             layout:   "pdf",
             formats:  [:html],
             page_size: "A4",
             orientation: "Landscape",
             margin: { top: 10, bottom: 10, left: 10, right: 10 },
             disposition: "attachment"
    end

    private

    def load_report_data
      @event = current_event

      shifts = Shift.joins(team: :sector)
                    .where(sectors: { event_id: @event.id })
                    .includes(:user, team: :sector)

      memberships = TeamMembership
                      .joins(team: :sector)
                      .where(sectors: { event_id: @event.id })
                      .includes(:event_function)

      membership_map = memberships.index_by { |tm| [tm.team_id, tm.user_id] }

      rows = {}
      shifts.each do |shift|
        tm    = membership_map[[shift.team_id, shift.user_id]]
        fn    = tm&.event_function
        hours = calculate_hours(shift)

        key = shift.user_id
        rows[key] ||= {
          user:          shift.user,
          function_name: fn&.name || "—",
          hourly_rate:   fn&.hourly_rate || 0,
          shifts:        [],
          total_hours:   0.0,
          total_value:   0.0
        }
        rows[key][:shifts]      << shift
        rows[key][:total_hours] += hours
        rows[key][:total_value] += hours * (fn&.hourly_rate || 0)
      end

      @rows        = rows.values.sort_by { |r| r[:user].name }
      @grand_total = @rows.sum { |r| r[:total_value] }
    end

    def calculate_hours(shift)
      s_min    = shift.start_time.hour * 60 + shift.start_time.min
      e_min    = shift.end_time.hour * 60   + shift.end_time.min
      end_date = shift.end_date.presence || shift.date

      # Span contínuo: dias inteiros × 1440 + diferença de minutos
      total_min = (end_date - shift.date).to_i * 1440 + e_min - s_min

      # Turno overnight no mesmo dia (sem end_date): ex. 22:00–06:00
      total_min += 1440 if total_min <= 0

      total_min.to_f / 60.0
    end
  end
end
