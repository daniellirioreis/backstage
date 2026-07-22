module Reports
  class PaymentsController < ApplicationController
    skip_before_action :require_current_event!, only: [:receipt, :receipt_pdf]
    before_action :set_payment, only: [:destroy, :receipt, :receipt_pdf]

    def create
      authorize :report, :manage_payments?

      @payment = Payment.new(payment_params)
      @payment.event   = current_event
      @payment.paid_by = current_user
      @payment.paid_at = Time.current
      @payment.date    = params.dig(:payment, :date).presence

      if @payment.waived?
        @payment.payment_method = nil
        @payment.amount         = 0
      end

      user_id = @payment.user_id
      anchor  = "payment-row-#{user_id}"

      # Guard: bloqueia se já existe pagamento para esse colaborador nesta data
      if @payment.date.present? && Payment.exists?(event: current_event, user_id: user_id, date: @payment.date)
        existing_user = User.find_by(id: user_id)
        return redirect_to referer_with_anchor(anchor, fallback: reports_closing_path(basis: @payment.basis)),
                           alert: "#{existing_user&.name || 'Colaborador'} já possui um pagamento registrado para esta data."
      end

      if @payment.save
        msg = @payment.waived? ? "#{@payment.user.name} marcado como dispensado." : "Pagamento de #{@payment.user.name} registrado com sucesso."
        redirect_to referer_with_anchor(anchor, fallback: reports_closing_path(basis: @payment.basis)),
                    notice: msg
      else
        redirect_to referer_with_anchor(anchor, fallback: reports_closing_path(basis: @payment.basis)),
                    alert: "Erro: #{@payment.errors.full_messages.to_sentence}"
      end
    end

    def destroy
      authorize :report, :manage_payments?
      user_id = @payment.user_id
      basis   = @payment.basis
      anchor = "payment-row-#{user_id}"
      @payment.destroy
      redirect_to referer_with_anchor(anchor, fallback: reports_closing_path(basis: basis)),
                  notice: "Pagamento removido."
    end

    def receipt
      # Colaborador pode ver o próprio comprovante; gestor/admin usa a policy normal
      authorize(:report, :view_receipt?) unless @payment.user_id == current_user.id
      render layout: false
    end

    def receipt_pdf
      authorize(:report, :view_receipt?) unless @payment.user_id == current_user.id
      render pdf:              "comprovante-#{@payment.user.name.parameterize}-#{@payment.event.name.parameterize}",
             template:         "reports/payments/receipt",
             layout:           false,
             formats:          [:html],
             page_size:        "A4",
             orientation:      "Portrait",
             margin:           { top: 0, bottom: 15, left: 0, right: 0 },
             disposition:      "attachment",
             print_media_type: true,
             background:       true,
             locals:           { pdf_mode: true }
    end

    private

    def set_payment
      @payment = Payment.find(params[:id])
    end

    def payment_params
      params.require(:payment).permit(:user_id, :date, :amount, :hours, :hourly_rate,
                                      :function_name, :payment_method, :basis, :notes,
                                      :waived, :waived_reason)
    end
  end
end
