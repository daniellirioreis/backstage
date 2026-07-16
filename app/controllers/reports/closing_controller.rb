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
      @basis             = params[:basis].presence_in(%w[shifts attendance cross manual]) || "cross"
      @sector_id         = params[:sector_id].presence
      @selected_date     = params[:date].presence
      @collaborator_name = params[:collaborator].presence
      @payment_status    = params[:payment_status].presence_in(%w[paid pending])
      if @basis == "manual"
        load_manual_data
      else
        load_report_data
      end
      if @collaborator_name.present?
        q     = @collaborator_name.downcase
        @rows = @rows.select { |r| r[:user].name.downcase.include?(q) }
      end
      if @payment_status == "paid"
        @rows = @rows.select { |r| @payment_by_user_date[[r[:user].id, @selected_date]] }
      elsif @payment_status == "pending"
        @rows = @rows.reject { |r| @payment_by_user_date[[r[:user].id, @selected_date]] }
      end
      if @rows_by_date && (@collaborator_name.present? || @payment_status.present?)
        user_ids = @rows.map { |r| r[:user].id }.to_set
        @rows_by_date = @rows_by_date.map do |group|
          group.merge(rows: group[:rows].select { |r| user_ids.include?(r[:user].id) })
        end.reject { |group| group[:rows].empty? }
      end
      @grand_total = @rows.sum { |r| r[:total_value].to_f } if @collaborator_name.present? || @payment_status.present?
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

    def save_manual
      return redirect_to(select_event_path, alert: "Selecione um evento.") unless current_event
      authorize :report, :closing?
      unless current_event.closed?
        redirect_to reports_closing_path, alert: "Disponível apenas para eventos encerrados." and return
      end

      date    = params[:date].presence
      entries = params[:entries] || {}
      saved = 0

      entries.each do |user_id, times|
        next if times[:started_at].blank? || times[:ended_at].blank?

        checked_in_at  = Time.zone.parse("#{date} #{times[:started_at]}")
        checked_out_at = Time.zone.parse("#{date} #{times[:ended_at]}")
        next unless checked_in_at && checked_out_at
        checked_out_at += 1.day if checked_out_at <= checked_in_at

        team_id = TeamMembership.joins(team: :sector)
                                .where(sectors: { event_id: current_event.id }, user_id: user_id)
                                .joins(:team).pick("teams.id")

        attendance = Attendance.find_or_initialize_by(
          event:           current_event,
          user_id:         user_id.to_i,
          checked_in_date: date
        )

        attendance.assign_attributes(
          checked_in_at:  checked_in_at,
          checked_out_at: checked_out_at,
          team_id:        team_id,
          source:         :manual
        )
        saved += 1 if attendance.save
      end

      msg = "#{saved} registro(s) salvo(s)."
      redirect_to reports_closing_path(basis: "manual", date: date, sector_id: params[:sector_id]),
                  notice: msg
    end

    def batch_pay
      return redirect_to(select_event_path, alert: "Selecione um evento.") unless current_event
      authorize :report, :manage_payments?

      basis          = params[:basis].presence_in(%w[shifts attendance cross]) || "cross"
      date_str       = params[:date].presence
      payment_method = params[:payment_method].presence || "pix"

      unless date_str
        return redirect_to reports_closing_path(basis: basis), alert: "Selecione uma data antes de pagar em lote."
      end

      @basis         = basis
      @selected_date = date_str
      load_report_data

      already_paid = Payment.where(event: current_event, date: date_str).pluck(:user_id).to_set
      pending_rows  = @rows.select { |r| r[:total_value].to_f > 0 && !already_paid.include?(r[:user].id) }

      if pending_rows.empty?
        return redirect_to reports_closing_path(basis: basis, date: date_str),
                           notice: "Nenhum colaborador pendente para pagar nesta data."
      end

      paid_count = 0
      errors     = []

      Payment.transaction do
        pending_rows.each do |row|
          p = Payment.new(
            event:          current_event,
            user:           row[:user],
            date:           date_str,
            amount:         row[:total_value].to_f.round(2),
            hourly_rate:    row[:hourly_rate].to_f.round(2),
            function_name:  row[:function_name],
            basis:          basis,
            payment_method: payment_method,
            paid_by:        current_user,
            paid_at:        Time.current,
            waived:         false
          )
          if p.save
            paid_count += 1
          else
            errors << "#{row[:user].name}: #{p.errors.full_messages.to_sentence}"
          end
        end
      end

      if errors.any?
        redirect_to reports_closing_path(basis: basis, date: date_str),
                    alert: "#{paid_count} pagamentos realizados. Erros: #{errors.join(' | ')}"
      else
        redirect_to reports_closing_path(basis: basis, date: date_str),
                    notice: "#{paid_count} pagamento#{"s" if paid_count != 1} realizado#{"s" if paid_count != 1} com sucesso."
      end
    end

    def finalize
      return redirect_to(select_event_path, alert: "Selecione um evento.") unless current_event
      authorize :report, :finalize_closing?
      unless current_event.closed?
        redirect_to reports_closing_path, alert: "Só é possível finalizar o fechamento de eventos encerrados."
        return
      end
      if current_event.closing_finalized_at?
        redirect_to reports_closing_path, alert: "O fechamento já está finalizado."
        return
      end

      # Verifica se todos os presentes (e não escalados) foram pagos
      @basis     = "cross"
      @sector_id = nil
      load_report_data

      paid_user_ids = Payment.where(event: current_event).pluck(:user_id).to_set
      unpaid = @rows.select { |row| row[:status] != :absent && !paid_user_ids.include?(row[:user].id) }
      if unpaid.any?
        names = unpaid.first(3).map { |r| r[:user].name }.join(", ")
        names += " e mais #{unpaid.size - 3}" if unpaid.size > 3
        redirect_to reports_closing_path,
          alert: "Não é possível finalizar: #{unpaid.size} colaborador(es) ainda não foram pagos (#{names})."
        return
      end

      current_event.update!(
        closing_finalized_at:    Time.current,
        closing_finalized_by_id: current_user.id
      )
      redirect_to reports_closing_path, notice: "Fechamento finalizado com sucesso!"
    end

    def reopen
      return redirect_to(select_event_path, alert: "Selecione um evento.") unless current_event
      authorize :report, :reopen_closing?
      current_event.update!(closing_finalized_at: nil, closing_finalized_by_id: nil)
      redirect_to reports_closing_path, notice: "Fechamento reaberto."
    end

    private

    def load_manual_data
      @event       = current_event
      @company     = @event.company
      @sectors     = Sector.where(event: @event).order(:name)
      @sector      = @sectors.find_by(id: @sector_id)
      load_available_dates
      @manual_date = @selected_date
      @rows        = []
      @grand_total = 0

      shifts = Shift.joins(team: :sector)
                    .where(sectors: { event_id: @event.id })
                    .then { |q| @manual_date ? q.where(date: @manual_date) : q }
                    .then { |q| @sector ? q.where(sectors: { id: @sector.id }) : q }
                    .includes(:user)

      memberships_map  = event_memberships.index_by(&:user_id)
      attendances_all  = Attendance.where(event: @event)
                                   .then { |q| @manual_date ? q.where(checked_in_date: @manual_date) : q }
      # index by [user_id, date] for multi-date lookup
      attendance_map   = attendances_all.index_by { |a| [a.user_id, a.checked_in_date.to_s] }

      build_row = lambda do |user_id, user_shifts, date_str|
        tm       = memberships_map[user_id]
        fn       = tm&.event_function
        att      = attendance_map[[user_id, date_str]]
        actual_h = att&.checked_out_at ? (att.checked_out_at - att.checked_in_at) / 3600.0 : nil
        {
          user:          user_shifts.first.user,
          function_name: fn&.name || "—",
          hourly_rate:   fn&.hourly_rate.to_f,
          shifts:        user_shifts.sort_by(&:start_time),
          attendance:    att,
          has_qr:        att&.qr_code?,
          has_manual:    att&.manual?,
          actual_hours:  actual_h,
          total_value:   actual_h ? actual_h * fn&.hourly_rate.to_f : 0
        }
      end

      if @manual_date
        shifts_by_user = shifts.group_by(&:user_id)
        @rows = shifts_by_user.map { |uid, us| build_row.call(uid, us, @manual_date) }
                              .sort_by { |r| r[:user].name }
        @rows_by_date  = nil
      else
        shifts_by_date = shifts.group_by { |s| s.date.to_s }
        @rows_by_date  = shifts_by_date.sort.map do |date_str, date_shifts|
          rows = date_shifts.group_by(&:user_id)
                            .map { |uid, us| build_row.call(uid, us, date_str) }
                            .sort_by { |r| r[:user].name }
          { date: Date.parse(date_str), date_str: date_str, rows: rows }
        end
        @rows = @rows_by_date.flat_map { |g| g[:rows] }
      end

      @grand_total = @rows.sum { |r| r[:total_value] }
      load_payments
    end

    def load_report_data
      @event    = current_event
      @company  = @event.company
      @sectors  = Sector.where(event: @event).order(:name)
      @sector   = @sectors.find_by(id: @sector_id)
      load_available_dates
      case @basis
      when "attendance" then load_by_attendance
      when "cross"      then load_by_cross
      else                   load_by_shifts
      end
      load_payments
    end

    def load_payments
      payments = Payment.where(event: @event).includes(:user)
      @payment_by_user_date = payments.index_by { |p| [p.user_id, p.date&.to_s] }
    end

    def load_available_dates
      @available_dates = Shift.joins(team: :sector)
                              .where(sectors: { event_id: @event.id })
                              .distinct.pluck(:date).sort
    end

    # ── Opção 1: por escalas cadastradas ──────────────────────────
    def load_by_shifts
      shifts = Shift.joins(team: :sector)
                    .where(sectors: { event_id: @event.id })
                    .then { |q| @sector ? q.where(sectors: { id: @sector.id }) : q }
                    .then { |q| @selected_date ? q.where(date: @selected_date) : q }
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
                              .then { |q| @selected_date ? q.where(checked_in_date: @selected_date) : q }
                              .includes(:user, :team)

      memberships    = event_memberships
      membership_map = memberships.index_by(&:user_id)

      # Carregar turnos escalados para calcular valor escalado por usuário
      shifts = Shift.joins(team: :sector)
                    .where(sectors: { event_id: @event.id })
                    .then { |q| @sector ? q.where(sectors: { id: @sector.id }) : q }
                    .then { |q| @selected_date ? q.where(date: @selected_date) : q }

      scheduled_value_by_user  = Hash.new(0.0)
      scheduled_hours_by_user  = Hash.new(0.0)
      scheduled_entries_by_user = Hash.new { |h, k| h[k] = [] }
      shifts.each do |shift|
        tm    = membership_map[shift.user_id]
        rate  = tm&.event_function&.hourly_rate.to_f
        hours = hours_from_shift(shift)
        scheduled_hours_by_user[shift.user_id]  += hours
        scheduled_entries_by_user[shift.user_id] << {
          start_time: shift.start_time.strftime("%H:%M"),
          end_time:   shift.end_time.strftime("%H:%M"),
          hours:      hours
        }
        next if rate.zero?
        scheduled_value_by_user[shift.user_id] += hours * rate
      end

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

      rows.each do |uid, row|
        row[:scheduled_value]   = scheduled_value_by_user[uid]
        row[:scheduled_hours]   = scheduled_hours_by_user[uid]
        row[:scheduled_entries] = scheduled_entries_by_user[uid]
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
                    .then { |q| @selected_date ? q.where(date: @selected_date) : q }
                    .includes(:user, team: :sector)

      # Carregar attendances — check-in já basta para presença
      attendances = Attendance.where(event: @event)
                              .then { |q| @sector ? q.joins(:team).where(teams: { sector_id: @sector.id }) : q }
                              .then { |q| @selected_date ? q.where(checked_in_date: @selected_date) : q }
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
        shift_rows[key] ||= { user: shift.user, fn: fn, scheduled_hours: 0.0, scheduled_value: 0.0, shift_entries: [] }
        shift_rows[key][:scheduled_hours]  += hours
        shift_rows[key][:scheduled_value]  += hours * (fn&.hourly_rate.to_f)
        shift_rows[key][:shift_entries]    << {
          label:      format_shift_label(shift),
          hours:      hours,
          start_time: shift.start_time.strftime("%H:%M"),
          end_time:   shift.end_time.strftime("%H:%M")
        }
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
          source:          att.source,
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
          scheduled_value:  sr&.dig(:scheduled_value) || 0.0,
          actual_hours:     actual,
          payable_hours:    payable,
          total_value:      payable * (fn&.hourly_rate || 0),
          status:           status,
          shift_entries:    sr&.dig(:shift_entries) || [],
          att_entries:      ar&.dig(:att_entries) || []
        }
      end

      # Status priority: unscheduled primeiro (precisam atenção), depois ausentes, depois presentes
      @rows        = rows.sort_by { |r| r[:user].name }
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
