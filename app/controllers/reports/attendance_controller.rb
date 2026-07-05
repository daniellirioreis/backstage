module Reports
  class AttendanceController < ApplicationController
    def index
      return redirect_to(select_event_path, alert: "Selecione um evento para continuar.") unless current_event
      authorize :report, :attendance_report?

      @event   = current_event
      @sectors = Sector.where(event: @event).order(:name)
      @sector  = @sectors.find_by(id: params[:sector_id])

      load_data
    end

    private

    def load_data
      # Todos os shifts do evento (filtrado por setor se necessário)
      shifts = Shift.joins(team: :sector)
                    .where(sectors: { event_id: @event.id })
                    .then { |q| @sector ? q.where(sectors: { id: @sector.id }) : q }
                    .includes(:user, team: :sector)

      # Todas as attendances do evento
      attendances = Attendance.where(event: @event)
                              .then { |q| @sector ? q.joins(:team).where(teams: { sector_id: @sector.id }) : q }
                              .includes(:user)

      # Agrupar shifts por usuário
      scheduled_by_user = Hash.new(0)
      sector_by_user    = {}
      team_by_user      = {}
      shifts.each do |s|
        scheduled_by_user[s.user_id] += 1
        sector_by_user[s.user_id] ||= s.team&.sector&.name
        team_by_user[s.user_id]   ||= s.team&.name
      end

      # Agrupar check-ins por usuário
      checkins_by_user = Hash.new(0)
      attendances.each { |a| checkins_by_user[a.user_id] += 1 }

      # Todos os usuários relevantes
      all_user_ids = (scheduled_by_user.keys + checkins_by_user.keys).uniq
      users = User.where(id: all_user_ids).index_by(&:id)

      @rows = all_user_ids.map do |uid|
        scheduled = scheduled_by_user[uid]
        present   = checkins_by_user[uid]
        absent    = [scheduled - present, 0].max
        pct       = scheduled > 0 ? (present.to_f / scheduled * 100).round : nil

        {
          user:      users[uid],
          sector:    sector_by_user[uid],
          team:      team_by_user[uid],
          scheduled: scheduled,
          present:   present,
          absent:    absent,
          pct:       pct
        }
      end.sort_by { |r| [r[:pct] || -1, r[:user]&.name.to_s] }

      @total_scheduled = @rows.sum { |r| r[:scheduled] }
      @total_present   = @rows.sum { |r| r[:present] }
      @overall_pct     = @total_scheduled > 0 ? (@total_present.to_f / @total_scheduled * 100).round : 0
    end
  end
end
