module Reports
  class PaymentsController < ApplicationController
    before_action :set_payment, only: [:destroy, :receipt, :receipt_pdf]

    def create
      authorize :report, :manage_payments?

      @payment = Payment.new(payment_params)
      @payment.event    = current_event
      @payment.paid_by  = current_user
      @payment.paid_at  = Time.current

      user_id = @payment.user_id
      if @payment.save
        redirect_to reports_closing_path(basis: @payment.basis, anchor: "payment-row-#{user_id}"),
                    notice: "Pagamento de #{@payment.user.name} registrado com sucesso."
      else
        redirect_to reports_closing_path(basis: @payment.basis, anchor: "payment-row-#{user_id}"),
                    alert: "Erro ao registrar pagamento: #{@payment.errors.full_messages.to_sentence}"
      end
    end

    def destroy
      authorize :report, :manage_payments?
      user_id = @payment.user_id
      basis   = @payment.basis
      @payment.destroy
      redirect_to reports_closing_path(basis: basis, anchor: "payment-row-#{user_id}"),
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
      params.require(:payment).permit(:user_id, :amount, :hours, :hourly_rate,
                                      :function_name, :payment_method, :basis, :notes)
    end
  end
end
