module Reports
  class AbsencesController < ApplicationController
    def index
      return redirect_to(select_event_path, alert: "Selecione um evento para continuar.") unless current_event
      authorize :report, :absences_report?

      @event   = current_event
      @sectors = Sector.where(event: @event).order(:name)
      @sector  = @sectors.find_by(id: params[:sector_id])

      # Filtro de data
      @date = params[:date].present? ? Date.parse(params[:date]) : Date.today rescue Date.today

      load_data
    end

    private

    def load_data
      # Shifts do dia filtrado
      shifts = Shift.joins(team: :sector)
                    .where(sectors: { event_id: @event.id })
                    .where(date: @date)
                    .then { |q| @sector ? q.where(sectors: { id: @sector.id }) : q }
                    .includes(:user, team: :sector)

      # Check-ins do dia
      checked_in_user_ids = Attendance.where(event: @event, checked_in_date: @date).pluck(:user_id).to_set

      # Quem estava escalado mas não fez check-in
      @rows = shifts.reject { |s| checked_in_user_ids.include?(s.user_id) }.map do |s|
        {
          user:       s.user,
          sector:     s.team&.sector&.name,
          team:       s.team&.name,
          date:       s.date,
          start_time: s.start_time,
          end_time:   s.end_time
        }
      end.sort_by { |r| [r[:sector].to_s, r[:user]&.name.to_s] }

      @total_scheduled = shifts.count
      @total_absent    = @rows.size
      @total_present   = @total_scheduled - @total_absent

      # Datas com turnos para o filtro de calendário
      @event_dates = Shift.joins(team: :sector)
                          .where(sectors: { event_id: @event.id })
                          .distinct.pluck(:date).sort
    end
  end
end
