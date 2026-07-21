class OnboardingController < ApplicationController
  skip_before_action :require_current_event!
  layout "onboarding"

  before_action :ensure_pending_onboarding

  # GET /onboarding/empresa
  def empresa
    return redirect_to onboarding_evento_path if current_user.companies.exists?
    @company = Company.new
  end

  # POST /onboarding/empresa
  def save_empresa
    return redirect_to onboarding_plano_path if current_user.companies.exists?

    @company = Company.new(company_params)
    if @company.save
      current_user.company_users.create!(company: @company, role: "owner")
      redirect_to onboarding_plano_path
    else
      render :empresa, status: :unprocessable_entity
    end
  end

  # GET /onboarding/plano
  def plano
    @company = current_user.companies.first
    redirect_to onboarding_empresa_path and return unless @company
    redirect_to onboarding_evento_path and return if @company.events.exists?
    @plans = Plan.order(:name)
  end

  # POST /onboarding/plano
  def save_plano
    @company = current_user.companies.first
    redirect_to onboarding_empresa_path and return unless @company

    plan_id = params[:plan_id].presence
    unless plan_id
      @plans = Plan.order(:name)
      flash.now[:alert] = "Selecione um plano para continuar."
      render :plano, status: :unprocessable_entity and return
    end

    plan = Plan.find(plan_id)
    @company.update!(plan: plan)

    if plan.price.to_f > 0
      begin
        asaas = AsaasService.new
        customer = asaas.find_or_create_customer(@company)
        subscription = asaas.create_subscription(
          customer_id: customer["id"],
          plan:        plan,
          company:     @company
        )
        @company.update!(
          asaas_customer_id:       customer["id"],
          asaas_subscription_id:   subscription["id"],
          subscription_status:     "pending",
          subscription_expires_at: Date.today + 7.days
        )
        redirect_to onboarding_pagamento_path
      rescue AsaasService::AsaasError => e
        @plans = Plan.order(:name)
        flash.now[:alert] = "Erro ao criar assinatura: #{e.message}"
        render :plano, status: :unprocessable_entity
      end
    else
      @company.update!(subscription_status: "active")
      redirect_to onboarding_evento_path
    end
  end

  # GET /onboarding/pagamento
  def pagamento
    @company = current_user.companies.where.not(asaas_subscription_id: [nil, ""]).first
    @company ||= current_user.company_users.includes(:company).first&.company
    redirect_to onboarding_empresa_path and return unless @company
    redirect_to onboarding_evento_path and return if @company.subscription_status == "active"

    if @company.asaas_subscription_id.present?
      begin
        asaas = AsaasService.new
        @pending_payment = asaas.pending_payment(@company.asaas_subscription_id)
      rescue AsaasService::AsaasError
        # silencioso — mostra página sem link
      end
    end
  end

  # POST /onboarding/verificar_pagamento
  # Consulta a API do Asaas e atualiza o status antes de liberar o acesso
  def verificar_pagamento
    @company = current_user.companies.where.not(asaas_subscription_id: [nil, ""]).first
    @company ||= current_user.company_users.includes(:company).first&.company
    redirect_to onboarding_empresa_path and return unless @company

    if @company.asaas_subscription_id.blank?
      return redirect_to onboarding_pagamento_path, alert: "Nenhuma assinatura encontrada."
    end

    begin
      asaas        = AsaasService.new
      subscription = asaas.get_subscription(@company.asaas_subscription_id)

      # Verifica se a assinatura pertence a esta empresa
      expected_ref = "company_#{@company.id}_plan_#{@company.plan_id}"
      if subscription["externalReference"].to_s != expected_ref
        return redirect_to onboarding_pagamento_path,
          alert: "Assinatura inválida para esta empresa."
      end

      all_payments = asaas.get("/payments", subscription: @company.asaas_subscription_id)
      confirmed = all_payments["data"].to_a.any? do |p|
        %w[RECEIVED CONFIRMED RECEIVED_IN_CASH].include?(p["status"].to_s.upcase)
      end

      if confirmed
        @company.update!(
          subscription_status:     "active",
          subscription_expires_at: Date.today + 30.days
        )
        redirect_to onboarding_evento_path, notice: "Pagamento confirmado! Bem-vindo ao Backstage."
      else
        redirect_to onboarding_pagamento_path,
          alert: "Pagamento ainda não confirmado. Aguarde alguns instantes e tente novamente."
      end
    rescue AsaasService::AsaasError => e
      redirect_to onboarding_pagamento_path, alert: "Erro ao verificar pagamento: #{e.message}"
    end
  end

  # GET /onboarding/evento
  def evento
    company = current_user.companies.first
    redirect_to onboarding_empresa_path and return unless company
    if company.events.exists?
      current_user.update_column(:onboarding_completed_at, Time.current)
      return redirect_to onboarding_done_path
    end
    @event = Event.new(company: company, start_date: Date.today, end_date: Date.today + 1)
  end

  # POST /onboarding/evento
  def save_evento
    company = current_user.companies.first
    redirect_to onboarding_empresa_path and return unless company

    # Se a empresa já tem eventos, pula a criação
    if company.events.exists?
      current_user.update_column(:onboarding_completed_at, Time.current)
      return redirect_to onboarding_done_path
    end

    @event = company.events.new(event_params)
    if @event.save
      session[:current_event_id] = @event.id
      current_user.update_column(:onboarding_completed_at, Time.current)
      redirect_to onboarding_done_path
    else
      @preset_events = []
      render :evento, status: :unprocessable_entity
    end
  end

  # POST /onboarding/evento/pular
  def skip_evento
    current_user.update_column(:onboarding_completed_at, Time.current)
    redirect_to onboarding_done_path
  end

  # GET /onboarding/concluido
  def done
    current_user.update_column(:onboarding_completed_at, Time.current) unless current_user.onboarding_complete?
  end

  private

  def ensure_pending_onboarding
    return if current_user.invitation_token.present? && current_user.invitation_accepted_at.present?
    redirect_to root_path
  end

  def company_params
    params.require(:company).permit(:name, :cnpj, :phone, :email, :city, :state, :plan_id)
  end

  def event_params
    params.require(:event).permit(:name, :location, :event_type, :start_date, :end_date)
  end
end
