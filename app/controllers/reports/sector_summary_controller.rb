module Reports
  class SectorSummaryController < ApplicationController
    def index
      return redirect_to(select_event_path, alert: "Selecione um evento para continuar.") unless current_event
      authorize :report, :sector_summary_report?

      @event   = current_event
      @sectors = Sector.where(event: @event).order(:name).includes(teams: :team_memberships)

      load_data
    end

    private

    def load_data
      # Colaboradores únicos por setor (via memberships)
      members_by_sector = TeamMembership.joins(team: :sector)
                                        .where(sectors: { event_id: @event.id })
                                        .group("sectors.id")
                                        .count

      # Shifts por setor → horas escaladas
      shifts = Shift.joins(team: :sector)
                    .where(sectors: { event_id: @event.id })
                    .includes(team: :sector)

      scheduled_hours_by_sector = Hash.new(0.0)
      shifts.each do |s|
        h = hours_from_shift(s)
        scheduled_hours_by_sector[s.team.sector_id] += h
      end

      # Attendances por setor → presença e horas reais
      attendances = Attendance.where(event: @event)
                              .joins(:team).includes(team: :sector)

      present_users_by_sector  = Hash.new { |h, k| h[k] = Set.new }
      actual_hours_by_sector   = Hash.new(0.0)
      attendances.each do |a|
        sid = a.team&.sector_id
        next unless sid
        present_users_by_sector[sid] << a.user_id
        if a.checked_out_at
          actual_hours_by_sector[sid] += (a.checked_out_at - a.checked_in_at) / 3600.0
        end
      end

      # Membros únicos esperados por setor (via shifts)
      expected_users_by_sector = Hash.new { |h, k| h[k] = Set.new }
      shifts.each { |s| expected_users_by_sector[s.team.sector_id] << s.user_id }

      @rows = @sectors.map do |sector|
        expected  = expected_users_by_sector[sector.id].size
        present   = present_users_by_sector[sector.id].size
        absent    = [expected - present, 0].max
        pct       = expected > 0 ? (present.to_f / expected * 100).round : nil
        sched_h   = scheduled_hours_by_sector[sector.id]
        actual_h  = actual_hours_by_sector[sector.id]

        {
          sector:           sector,
          members:          members_by_sector[sector.id] || 0,
          expected:         expected,
          present:          present,
          absent:           absent,
          pct:              pct,
          scheduled_hours:  sched_h,
          actual_hours:     actual_h
        }
      end

      @total_expected  = @rows.sum { |r| r[:expected] }
      @total_present   = @rows.sum { |r| r[:present] }
      @total_sched_h   = @rows.sum { |r| r[:scheduled_hours] }
      @total_actual_h  = @rows.sum { |r| r[:actual_hours] }
      @overall_pct     = @total_expected > 0 ? (@total_present.to_f / @total_expected * 100).round : 0
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
