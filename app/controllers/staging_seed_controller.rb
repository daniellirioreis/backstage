class StagingSeedController < ApplicationController
  skip_before_action :authenticate_user!
  skip_after_action  :verify_authorized

  SEED_TOKEN = "demo-coord-2026".freeze

  def coordinator
    allowed = Rails.env.development? || ENV["ALLOW_SEED_ENDPOINT"] == "true"
    unless allowed
      return render plain: "Not available", status: :forbidden
    end

    unless params[:token] == SEED_TOKEN
      return render plain: "Token inválido", status: :unauthorized
    end

    result = StagingSeedService.run_coordinator_demo
    render plain: result, content_type: "text/plain"
  rescue => e
    render plain: "Erro: #{e.message}\n#{e.backtrace.first(5).join("\n")}", status: :internal_server_error
  end
end
