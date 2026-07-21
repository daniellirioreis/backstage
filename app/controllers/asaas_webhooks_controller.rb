class AsaasWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  skip_before_action :require_current_event!
  skip_before_action :check_company_plan!

  def receive
    payload = JSON.parse(request.body.read)
    event   = payload["event"]
    payment = payload["payment"]

    # Encontra a empresa pela referência externa da assinatura
    subscription_id = payment&.dig("subscription")
    company = Company.find_by(asaas_subscription_id: subscription_id) if subscription_id

    if company
      case event
      when "PAYMENT_CONFIRMED", "PAYMENT_RECEIVED"
        company.update!(
          subscription_status:     "active",
          subscription_expires_at: Date.today + 30.days
        )
      when "PAYMENT_OVERDUE"
        company.update!(subscription_status: "overdue")
      when "SUBSCRIPTION_DELETED", "PAYMENT_DELETED"
        company.update!(
          subscription_status:    "cancelled",
          asaas_subscription_id:  nil
        )
      end
    end

    head :ok
  rescue JSON::ParserError
    head :bad_request
  end
end
