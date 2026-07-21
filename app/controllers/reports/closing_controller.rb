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
      @basis         = params[:basis].presence_in(%w[shifts attendance cross]) || "cross"
      @sector_id     = params[:sector_id].presence
      @selected_date = params[:date].presence
      load_report_data
      load_payments
      render pdf:         "fechamento-#{@event.name.parameterize}-#{@basis}-#{@selected_date || Date.today.strftime('%Y%m%d')}",
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
      @basis         = params[:basis].presence_in(%w[shifts attendance cross]) || "cross"
      @sector_id     = params[:sector_id].presence
      @selected_date = params[:date].presence
      load_report_data
      load_payments

      basis_label = { "cross" => "Cruzamento", "attendance" => "Check-in/out", "shifts" => "Escalas" }[@basis]
      filename    = "fechamento-#{@event.name.parameterize}-#{@basis}-#{Date.today.strftime('%Y%m%d')}.xlsx"

      package = Axlsx::Package.new
      wb      = package.workbook

      # Estilos
      styles = wb.styles
      header_style  = styles.add_style bg_color: "18181b", fg_color: "FFFFFF", b: true, sz: 10,
                                        alignment: { horizontal: :center, vertical: :center, wrap_text: true },
                                        border: { style: :thin, color: "CCCCCC" }
      title_style   = styles.add_style b: true, sz: 14, alignment: { horizontal: :left }
      subtitle_style= styles.add_style sz: 10, fg_color: "71717A"
      currency_style= styles.add_style num_fmt: 4, alignment: { horizontal: :right }   # #,##0.00
      hours_style   = styles.add_style num_fmt: 2, alignment: { horizontal: :right }   # 0.00
      center_style  = styles.add_style alignment: { horizontal: :center }
      paid_style    = styles.add_style bg_color: "DCFCE7", fg_color: "166534", b: true,
                                        alignment: { horizontal: :center }
      pending_style = styles.add_style bg_color: "FFF7ED", fg_color: "B45309", b: true,
                                        alignment: { horizontal: :center }
      absent_style  = styles.add_style bg_color: "FEE2E2", fg_color: "DC2626", b: true,
                                        alignment: { horizontal: :center }
      total_style   = styles.add_style bg_color: "F4F4F5", b: true, sz: 10,
                                        alignment: { horizontal: :right },
                                        border: { style: :thin, color: "CCCCCC" }
      total_cur_style = styles.add_style bg_color: "F4F4F5", b: true, sz: 10,
                                          num_fmt: 4, alignment: { horizontal: :right },
                                          border: { style: :thin, color: "CCCCCC" }
      label_total_style = styles.add_style bg_color: "F4F4F5", b: true, sz: 10,
                                            border: { style: :thin, color: "CCCCCC" }
      normal_style  = styles.add_style sz: 10

      # ── Aba principal: todos os colaboradores ───────────────────────
      wb.add_worksheet(name: "Fechamento #{basis_label}") do |sheet|
        # Cabeçalho do relatório
        sheet.add_row ["Fechamento de Pagamentos — #{@event.name}"], style: title_style
        sheet.add_row ["Base de cálculo: #{basis_label}  |  Exportado em: #{l(Date.today, format: :long)}"], style: subtitle_style
        sheet.add_row []

        # Headers das colunas
        if @basis == "cross"
          cols = ["Nome", "CPF", "Função", "Status", "Hs. Escaladas", "Hs. Trabalhadas", "Hs. a Pagar", "Valor/h (R$)", "Valor Orçado (R$)", "Valor a Pagar (R$)", "Status Pagamento", "Data Ref.", "Forma Pagamento", "Valor Pago (R$)", "Diferença (R$)"]
        elsif @basis == "attendance"
          cols = ["Nome", "CPF", "Função", "Hs. Escaladas", "Valor Orçado (R$)", "Check-in", "Check-out", "Hs. Trabalhadas", "Valor/h (R$)", "Valor a Pagar (R$)", "Status Pagamento", "Data Ref.", "Forma Pagamento", "Valor Pago (R$)", "Diferença (R$)"]
        else
          cols = ["Nome", "CPF", "Função", "Hs. Escaladas", "Valor/h (R$)", "Valor a Pagar (R$)", "Status Pagamento", "Data Ref.", "Forma Pagamento", "Valor Pago (R$)", "Diferença (R$)"]
        end
        sheet.add_row cols, style: header_style
        sheet.rows.last.height = 28

        status_labels = { present: "Presente", absent: "Ausente", unscheduled: "Não escalado" }
        method_labels = { "pix" => "PIX", "cash" => "Dinheiro", "bank_transfer" => "Transferência" }

        @rows.each do |row|
          payment    = @payment_by_user_date[[row[:user].id, @selected_date]]
          paid_amt   = payment&.amount.to_f
          value      = row[:total_value].to_f
          diff       = paid_amt - value

          pay_status = if payment&.waived?
                         "Dispensado"
                       elsif payment
                         "Pago"
                       else
                         row[:status] == :absent ? "Ausente" : "Pendente"
                       end

          pay_style = case pay_status
                      when "Pago"       then paid_style
                      when "Pendente"   then pending_style
                      when "Ausente"    then absent_style
                      else center_style
                      end

          if @basis == "cross"
            sheet.add_row [
              row[:user].name,
              row[:user].cpf.to_s.gsub(/(\d{3})(\d{3})(\d{3})(\d{2})/, '\1.\2.\3-\4'),
              row[:function_name],
              status_labels[row[:status]] || "",
              row[:scheduled_hours].to_f,
              row[:actual_hours].to_f,
              row[:payable_hours].to_f,
              row[:hourly_rate].to_f,
              row[:scheduled_value].to_f,
              value,
              pay_status,
              payment&.date ? l(payment.date, format: :short) : "",
              method_labels[payment&.payment_method] || "",
              payment && !payment.waived? ? paid_amt : nil,
              payment && !payment.waived? ? diff : nil
            ], style: [normal_style, normal_style, normal_style, center_style,
                       hours_style, hours_style, hours_style, currency_style,
                       currency_style, currency_style, pay_style, center_style,
                       center_style, currency_style, currency_style]
          elsif @basis == "attendance"
            first_entry = row[:entries]&.first
            sheet.add_row [
              row[:user].name,
              row[:user].cpf.to_s.gsub(/(\d{3})(\d{3})(\d{3})(\d{2})/, '\1.\2.\3-\4'),
              row[:function_name],
              row[:scheduled_hours].to_f,
              row[:scheduled_value].to_f,
              first_entry&.dig(:checked_in) || "",
              first_entry&.dig(:checked_out) || "",
              row[:actual_hours].to_f,
              row[:hourly_rate].to_f,
              value,
              pay_status,
              payment&.date ? l(payment.date, format: :short) : "",
              method_labels[payment&.payment_method] || "",
              payment && !payment.waived? ? paid_amt : nil,
              payment && !payment.waived? ? diff : nil
            ], style: [normal_style, normal_style, normal_style, hours_style,
                       currency_style, center_style, center_style, hours_style,
                       currency_style, currency_style, pay_style, center_style,
                       center_style, currency_style, currency_style]
          else
            sheet.add_row [
              row[:user].name,
              row[:user].cpf.to_s.gsub(/(\d{3})(\d{3})(\d{3})(\d{2})/, '\1.\2.\3-\4'),
              row[:function_name],
              row[:total_hours].to_f,
              row[:hourly_rate].to_f,
              value,
              pay_status,
              payment&.date ? l(payment.date, format: :short) : "",
              method_labels[payment&.payment_method] || "",
              payment && !payment.waived? ? paid_amt : nil,
              payment && !payment.waived? ? diff : nil
            ], style: [normal_style, normal_style, normal_style, hours_style,
                       currency_style, currency_style, pay_style, center_style,
                       center_style, currency_style, currency_style]
          end
        end

        # Linha de totais
        data_start = 5
        data_end   = 4 + @rows.size
        ncols      = cols.size

        if @basis == "cross"
          sheet.add_row [
            "TOTAL (#{@rows.size} colaboradores)", "", "", "",
            "=SUM(E#{data_start}:E#{data_end})",
            "=SUM(F#{data_start}:F#{data_end})",
            "=SUM(G#{data_start}:G#{data_end})",
            "",
            "=SUM(I#{data_start}:I#{data_end})",
            "=SUM(J#{data_start}:J#{data_end})",
            "", "", "",
            "=SUM(N#{data_start}:N#{data_end})",
            "=SUM(O#{data_start}:O#{data_end})"
          ], style: [label_total_style, total_style, total_style, total_style,
                     total_style, total_style, total_style, total_style,
                     total_cur_style, total_cur_style,
                     total_style, total_style, total_style,
                     total_cur_style, total_cur_style]
        elsif @basis == "attendance"
          sheet.add_row [
            "TOTAL (#{@rows.size} colaboradores)", "", "",
            "=SUM(D#{data_start}:D#{data_end})",
            "=SUM(E#{data_start}:E#{data_end})",
            "", "",
            "=SUM(H#{data_start}:H#{data_end})",
            "",
            "=SUM(J#{data_start}:J#{data_end})",
            "", "", "",
            "=SUM(N#{data_start}:N#{data_end})",
            "=SUM(O#{data_start}:O#{data_end})"
          ], style: [label_total_style, total_style, total_style,
                     total_style, total_cur_style,
                     total_style, total_style, total_style, total_style,
                     total_cur_style,
                     total_style, total_style, total_style,
                     total_cur_style, total_cur_style]
        else
          sheet.add_row [
            "TOTAL (#{@rows.size} colaboradores)", "", "",
            "=SUM(D#{data_start}:D#{data_end})",
            "",
            "=SUM(F#{data_start}:F#{data_end})",
            "", "", "",
            "=SUM(J#{data_start}:J#{data_end})",
            "=SUM(K#{data_start}:K#{data_end})"
          ], style: [label_total_style, total_style, total_style,
                     total_style, total_style, total_cur_style,
                     total_style, total_style, total_style,
                     total_cur_style, total_cur_style]
        end

        # Larguras das colunas
        col_widths = if @basis == "cross"
          [30, 16, 18, 14, 13, 14, 13, 12, 16, 16, 13, 11, 16, 14, 13]
        elsif @basis == "attendance"
          [30, 16, 18, 13, 16, 10, 10, 14, 12, 16, 13, 11, 16, 14, 13]
        else
          [30, 16, 18, 13, 12, 16, 13, 11, 16, 14, 13]
        end
        col_widths.each_with_index { |w, i| sheet.column_info[i].width = w }

        # Freeze header
        sheet.sheet_view.pane do |p|
          p.top_left_cell = "A5"
          p.state         = :frozen
          p.y_split       = 4
        end
      end

      # ── Aba de pagamentos realizados ─────────────────────────────────
      payments_all = Payment.where(event: @event).includes(:user, :paid_by).order(:date, "users.name")
      wb.add_worksheet(name: "Pagamentos Realizados") do |sheet|
        sheet.add_row ["Pagamentos Realizados — #{@event.name}"], style: title_style
        sheet.add_row ["Exportado em: #{l(Date.today, format: :long)}"], style: subtitle_style
        sheet.add_row []
        sheet.add_row ["Data", "Colaborador", "CPF", "Função", "Base", "Forma Pgto", "Valor (R$)", "Dispensado", "Registrado por", "Data Registro"],
                       style: header_style
        sheet.rows.last.height = 28

        payments_all.each do |p|
          sheet.add_row [
            p.date ? l(p.date, format: :short) : "—",
            p.user.name,
            p.user.cpf.to_s.gsub(/(\d{3})(\d{3})(\d{3})(\d{2})/, '\1.\2.\3-\4'),
            p.function_name || "—",
            { "cross" => "Cruzamento", "attendance" => "Check-in/out", "shifts" => "Escalas", "manual" => "Manual" }[p.basis] || p.basis,
            p.waived? ? "—" : (p.payment_method == "pix" ? "PIX" : p.payment_method == "cash" ? "Dinheiro" : "Transferência"),
            p.waived? ? nil : p.amount.to_f,
            p.waived? ? "Sim (#{p.waived_reason})" : "Não",
            p.paid_by&.name || "—",
            l(p.paid_at.to_date, format: :short)
          ], style: [center_style, normal_style, normal_style, normal_style,
                     center_style, center_style, currency_style, center_style,
                     normal_style, center_style]
        end

        data_start = 5
        data_end   = 4 + payments_all.size
        sheet.add_row ["TOTAL", "", "", "", "", "",
                        "=SUM(G#{data_start}:G#{data_end})", "", "", ""],
                       style: [label_total_style, total_style, total_style, total_style,
                               total_style, total_style, total_cur_style, total_style,
                               total_style, total_style]

        [10, 28, 16, 18, 14, 14, 14, 10, 24, 14].each_with_index { |w, i| sheet.column_info[i].width = w }

        sheet.sheet_view.pane do |p|
          p.top_left_cell = "A5"
          p.state         = :frozen
          p.y_split       = 4
        end
      end

      send_data package.to_stream.read,
                filename:    filename,
                type:        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
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

    def auto_save_manual_row
      return render json: { error: "Evento não selecionado" }, status: 422 unless current_event
      authorize :report, :closing?

      user_id    = params[:user_id].to_i
      date       = params[:date].presence
      started_at = params[:started_at].presence
      ended_at   = params[:ended_at].presence

      return render json: { error: "Campos incompletos" }, status: 422 unless user_id > 0 && date && started_at && ended_at

      checked_in_at  = Time.zone.parse("#{date} #{started_at}")
      checked_out_at = Time.zone.parse("#{date} #{ended_at}")
      return render json: { error: "Horários inválidos" }, status: 422 unless checked_in_at && checked_out_at

      checked_out_at += 1.day if checked_out_at <= checked_in_at

      team_id = TeamMembership.joins(team: :sector)
                              .where(sectors: { event_id: current_event.id }, user_id: user_id)
                              .joins(:team).pick("teams.id")

      attendance = Attendance.find_or_initialize_by(
        event:           current_event,
        user_id:         user_id,
        checked_in_date: date
      )

      attendance.assign_attributes(
        checked_in_at:  checked_in_at,
        checked_out_at: checked_out_at,
        team_id:        team_id,
        source:         :manual
      )

      if attendance.save
        hours = (checked_out_at - checked_in_at) / 3600.0
        tm    = TeamMembership.joins(team: :sector)
                              .where(sectors: { event_id: current_event.id }, user_id: user_id)
                              .includes(:event_function).first
        rate  = tm&.event_function&.hourly_rate.to_f
        value = hours * rate
        uid   = "#{user_id}d#{date.gsub('-', '')}"

        row = { user:          User.find(user_id),
                function_name: tm&.event_function&.name || "—",
                hourly_rate:   rate,
                total_value:   value,
                shifts:        [] }

        payment_html = render_to_string(
          partial: 'reports/closing/payment_cell',
          locals:  { payment: nil, row: row, uid: uid, rate: rate,
                     basis: 'manual', finalized: current_event.closing_finalized_at?, date: date }
        )

        render json: { ok: true, hours: hours.round(2), value: value.round(2),
                       uid: uid, payment_html: payment_html }
      else
        render json: { error: attendance.errors.full_messages.to_sentence }, status: 422
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
      @payment_by_user_date = {}
      undated = []

      payments.each do |p|
        if p.date.present?
          @payment_by_user_date[[p.user_id, p.date.to_s]] = p
        else
          undated << p
          @payment_by_user_date[[p.user_id, nil]] = p
        end
      end

      # Pagamentos sem data (legado): torná-los visíveis em qualquer filtro de data
      unless undated.empty?
        all_dates = (@available_dates || []).map(&:to_s)
        undated.each do |p|
          all_dates.each { |d| @payment_by_user_date[[p.user_id, d]] ||= p }
        end
      end
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
