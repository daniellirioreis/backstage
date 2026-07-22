class SubscriptionsController < ApplicationController
  skip_before_action :require_current_event!
  before_action :set_company
  before_action :require_billing_access!

  # GET /subscription
  def show
    @plans = Plan.where("price > 0").order(:price)
    @asaas = AsaasService.new

    if @company.asaas_subscription_id.present?
      begin
        @subscription = @asaas.get_subscription(@company.asaas_subscription_id)
        @pending_payment = @asaas.pending_payment(@company.asaas_subscription_id)
      rescue AsaasService::AsaasError => e
        flash.now[:alert] = "Não foi possível consultar sua assinatura: #{e.message}"
      end
    end
  end

  # POST /subscription
  # Assina um plano (cria cliente + assinatura no Asaas)
  def create
    plan = Plan.find_by(id: params[:plan_id])
    return redirect_to subscription_path, alert: "Plano inválido." unless plan
    return redirect_to subscription_path, alert: "Plano gratuito não requer assinatura." if plan.price.to_f <= 0

    asaas = AsaasService.new

    begin
      # 1. Cria ou recupera o cliente no Asaas
      customer = if @company.asaas_customer_id.present?
        { "id" => @company.asaas_customer_id }
      else
        asaas.find_or_create_customer(@company)
      end

      # 2. Cancela assinatura anterior se existir
      if @company.asaas_subscription_id.present?
        asaas.cancel_subscription(@company.asaas_subscription_id) rescue nil
      end

      # 3. Cria nova assinatura
      subscription = asaas.create_subscription(
        customer_id: customer["id"],
        plan:        plan,
        company:     @company
      )

      # 4. Atualiza empresa
      @company.update!(
        plan:                    plan,
        asaas_customer_id:       customer["id"],
        asaas_subscription_id:   subscription["id"],
        subscription_status:     "pending",
        subscription_expires_at: Date.today + 30.days
      )

      redirect_to subscription_path,
        notice: "Assinatura criada! Efetue o pagamento via PIX para ativar seu plano."

    rescue AsaasService::AsaasError => e
      redirect_to subscription_path, alert: "Erro ao criar assinatura: #{e.message}"
    end
  end

  # POST /subscription/verificar
  def verificar
    if @company.asaas_subscription_id.blank?
      return redirect_to subscription_path, alert: "Nenhuma assinatura encontrada."
    end

    begin
      asaas    = AsaasService.new
      subscription = asaas.get_subscription(@company.asaas_subscription_id)

      expected_ref = "company_#{@company.id}_plan_#{@company.plan_id}"
      if subscription["externalReference"].to_s != expected_ref
        return redirect_to subscription_path, alert: "Assinatura inválida para esta empresa."
      end

      # Busca todos os pagamentos da assinatura e verifica se algum foi recebido/confirmado
      all_payments = asaas.get("/payments", subscription: @company.asaas_subscription_id)
      confirmed = all_payments["data"].to_a.any? do |p|
        %w[RECEIVED CONFIRMED RECEIVED_IN_CASH].include?(p["status"].to_s.upcase)
      end

      if confirmed
        @company.update!(
          subscription_status:     "active",
          subscription_expires_at: Date.today + 30.days
        )
        redirect_to root_path, notice: "Pagamento confirmado! Acesso liberado."
      else
        redirect_to subscription_path, alert: "Pagamento ainda não confirmado. Aguarde alguns instantes e tente novamente."
      end
    rescue AsaasService::AsaasError => e
      redirect_to subscription_path, alert: "Erro ao verificar: #{e.message}"
    end
  end

  # DELETE /subscription
  def destroy
    return redirect_to subscription_path, alert: "Nenhuma assinatura ativa." unless @company.asaas_subscription_id.present?

    begin
      AsaasService.new.cancel_subscription(@company.asaas_subscription_id)
      @company.update!(
        asaas_subscription_id:  nil,
        subscription_status:    "cancelled",
        subscription_expires_at: nil
      )
      redirect_to subscription_path, notice: "Assinatura cancelada."
    rescue AsaasService::AsaasError => e
      redirect_to subscription_path, alert: "Erro ao cancelar: #{e.message}"
    end
  end

  private

  def require_billing_access!
    return if current_user.admin?
    role = current_user.company_role_for(@company)
    unless %w[owner manager].include?(role)
      redirect_to root_path, alert: "Você não tem permissão para acessar a assinatura."
    end
  end

  def set_company
    # Prioriza empresa com assinatura pendente/inativa/em atraso (precisa de ação)
    # depois empresa com qualquer assinatura vinculada, por fim a primeira empresa por papel
    @company = current_user.companies
                           .where.not(asaas_subscription_id: [nil, ""])
                           .where.not(subscription_status: "active")
                           .order(:id).first
    @company ||= current_user.companies
                             .where.not(asaas_subscription_id: [nil, ""])
                             .order(:id).first
    @company ||= current_user.company_users
                             .order(Arel.sql("CASE role WHEN 'owner' THEN 0 WHEN 'manager' THEN 1 ELSE 2 END"))
                             .includes(:company).first&.company
    redirect_to root_path, alert: "Nenhuma empresa associada." unless @company
  end
end
