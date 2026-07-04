require "csv"

module Reports
  class ClosingController < ApplicationController
    def index
      return redirect_to(select_event_path, alert: "Selecione um evento para continuar.") unless current_event
      authorize :report, :closing?
      unless current_event.closed?
        redirect_to event_path(current_event), alert: "O Fechamento só está disponível após o evento ser encerrado."
        return
      end
      @basis      = params[:basis].presence_in(%w[shifts attendance cross]) || "cross"
      @sector_id  = params[:sector_id].presence
      load_report_data
    end

    def print
      return redirect_to(select_event_path, alert: "Selecione um evento para continuar.") unless current_event
      authorize :report, :closing?
      unless current_event.closed?
        redirect_to event_path(current_event), alert: "O Fechamento só está disponível após o evento ser encerrado."
        return
      end
      @basis     = params[:basis].presence_in(%w[shifts attendance cross]) || "cross"
      @sector_id = params[:sector_id].presence
      load_report_data
      render pdf:         "fechamento-#{@event.name.parameterize}-#{@basis}",
             template:    "reports/closing/print",
             layout:      "pdf",
             formats:     [:html],
             page_size:   "A4",
             orientation: "Landscape",
             margin:      { top: 10, bottom: 10, left: 10, right: 10 },
             disposition: "attachment"
    end

    def export
      return redirect_to(select_event_path, alert: "Selecione um evento para continuar.") unless current_event
      authorize :report, :closing?
      unless current_event.closed?
        redirect_to event_path(current_event), alert: "O Fechamento só está disponível após o evento ser encerrado."
        return
      end
      @basis     = params[:basis].presence_in(%w[shifts attendance cross]) || "cross"
      @sector_id = params[:sector_id].presence
      load_report_data

      is_cross = @basis == "cross"
      headers = ["Nome", "CPF", "Função", "Valor/hora (R$)"]
      headers += ["Hs. Escaladas", "Hs. Reais", "Hs. a Pagar", "Status Presença"] if is_cross
      headers += ["Total Horas", "Total a Pagar (R$)"] unless is_cross
      headers += ["Total a Pagar (R$)"] if is_cross
      headers += ["Status Pagamento", "Forma Pagamento", "Data Pagamento"]

      csv_data = CSV.generate(col_sep: ";", encoding: "UTF-8") do |csv|
        csv << headers
        @rows.each do |row|
          payment = @payment_by_user[row[:user].id]
          hourly_rate = row[:hourly_rate].to_f
          line = [
            row[:user].name,
            row[:user].cpf.to_s.gsub(/(\d{3})(\d{3})(\d{3})(\d{2})/, '\1.\2.\3-\4'),
            row[:function_name],
            format("%.2f", hourly_rate)
          ]
          if is_cross
            status_label = { present: "Presente", absent: "Ausente", unscheduled: "Não escalado" }[row[:status]] || ""
            line += [
              format("%.2f", row[:scheduled_hours].to_f),
              format("%.2f", row[:actual_hours].to_f),
              format("%.2f", row[:payable_hours].to_f),
              status_label,
              format("%.2f", row[:total_value].to_f)
            ]
          else
            line += [
              format("%.2f", row[:total_hours].to_f),
              format("%.2f", row[:total_value].to_f)
            ]
          end
          line += [
            payment ? "Pago" : "Pendente",
            payment&.method_label || "",
            payment ? l(payment.paid_at.to_date, format: :short) : ""
          ]
          csv << line
        end
      end

      filename = "pagamentos-#{@event.name.parameterize}-#{@basis}-#{Date.today.strftime('%Y%m%d')}.csv"
      send_data "\xEF\xBB\xBF" + csv_data,
                filename: filename,
                type: "text/csv; charset=utf-8",
                disposition: "attachment"
    end

    private

    def load_report_data
      @event    = current_event
      @company  = @event.company
      @sectors  = Sector.where(event: @event).order(:name)
      @sector   = @sectors.find_by(id: @sector_id)
      case @basis
      when "attendance" then load_by_attendance
      when "cross"      then load_by_cross
      else                   load_by_shifts
      end
      load_payments
    end

    def load_payments
      payments = Payment.where(event: @event).includes(:user)
      @payment_by_user = payments.index_by(&:user_id)
    end

    # ── Opção 1: por escalas cadastradas ──────────────────────────
    def load_by_shifts
      shifts = Shift.joins(team: :sector)
                    .where(sectors: { event_id: @event.id })
                    .then { |q| @sector ? q.where(sectors: { id: @sector.id }) : q }
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
                              .then { |q| @sector ? q.joins(:team).where(teams: { sector_id: @sector.id }) : q }
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

    # ── Opção 3: cruzamento escalas + presença ────────────────────
    def load_by_cross
      # Carregar shifts
      shifts = Shift.joins(team: :sector)
                    .where(sectors: { event_id: @event.id })
                    .then { |q| @sector ? q.where(sectors: { id: @sector.id }) : q }
                    .includes(:user, team: :sector)

      # Carregar attendances — check-in já basta para presença
      attendances = Attendance.where(event: @event)
                              .then { |q| @sector ? q.joins(:team).where(teams: { sector_id: @sector.id }) : q }
                              .includes(:user, :team)

      memberships    = event_memberships
      membership_map = memberships.index_by { |tm| [tm.team_id, tm.user_id] }
      fn_by_user     = memberships.index_by(&:user_id)

      # Indexar shifts por user
      shift_rows = {}
      shifts.each do |shift|
        tm    = membership_map[[shift.team_id, shift.user_id]]
        fn    = tm&.event_function
        hours = hours_from_shift(shift)
        key   = shift.user_id
        shift_rows[key] ||= { user: shift.user, fn: fn, scheduled_hours: 0.0, shift_entries: [] }
        shift_rows[key][:scheduled_hours] += hours
        shift_rows[key][:shift_entries] << { label: format_shift_label(shift), hours: hours }
      end

      # Indexar attendances por user — check-in já conta como presença
      att_rows = {}
      attendances.each do |att|
        hours = att.checked_out_at ? (att.checked_out_at - att.checked_in_at) / 3600.0 : nil
        key   = att.user_id
        att_rows[key] ||= { user: att.user, actual_hours: 0.0, att_entries: [], missing_checkout: false }
        att_rows[key][:actual_hours] += hours || 0.0
        att_rows[key][:missing_checkout] = true unless att.checked_out_at
        att_rows[key][:att_entries] << {
          date:            l(att.checked_in_date, format: :short),
          checked_in:      att.checked_in_at.strftime("%H:%M"),
          checked_out:     att.checked_out_at&.strftime("%H:%M"),
          hours:           hours,
          missing_checkout: att.checked_out_at.nil?
        }
      end

      all_user_ids = (shift_rows.keys + att_rows.keys).uniq
      rows = all_user_ids.map do |uid|
        sr  = shift_rows[uid]
        ar  = att_rows[uid]
        tm  = fn_by_user[uid]
        fn  = sr&.dig(:fn) || tm&.event_function
        user = sr&.dig(:user) || ar&.dig(:user)

        scheduled        = sr&.dig(:scheduled_hours) || 0.0
        actual           = ar&.dig(:actual_hours) || 0.0
        missing_checkout = ar&.dig(:missing_checkout)

        status =
          if ar && sr    then :present       # fez check-in (com ou sem escala)
          elsif ar        then :unscheduled  # check-in sem escala (ex: substituto)
          else             :absent           # tem escala, SEM check-in
          end

        # Horas a pagar:
        #   presente com checkout  → horas reais
        #   presente sem checkout  → horas da escala como referência
        #   ausente                → 0
        #   não escalado           → horas reais (se tem checkout), senão 0
        payable = case status
                  when :present
                    missing_checkout ? scheduled : actual
                  when :absent
                    0.0
                  when :unscheduled
                    actual
                  end

        {
          user:             user,
          function_name:    fn&.name || "—",
          hourly_rate:      fn&.hourly_rate || 0,
          scheduled_hours:  scheduled,
          actual_hours:     actual,
          payable_hours:    payable,
          total_value:      payable * (fn&.hourly_rate || 0),
          status:           status,
          shift_entries:    sr&.dig(:shift_entries) || [],
          att_entries:      ar&.dig(:att_entries) || []
        }
      end

      # Status priority: unscheduled primeiro (precisam atenção), depois ausentes, depois presentes
      @rows        = rows.sort_by { |r| [[:unscheduled, :absent, :present].index(r[:status]), r[:user].name] }
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
