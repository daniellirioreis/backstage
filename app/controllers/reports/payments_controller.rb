module Reports
  class PaymentsController < ApplicationController
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
      anchor = "payment-row-#{user_id}"
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
      authorize :report, :view_receipt?
      render layout: false
    end

    def receipt_pdf
      authorize :report, :view_receipt?
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
