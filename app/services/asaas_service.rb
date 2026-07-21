require "net/http"
require "json"

# Wrapper para a API do Asaas.
# Documentação: https://docs.asaas.com
#
# Configurar em credentials ou ENV:
#   ASAAS_API_KEY  → chave de API (começa com $aact_...)
#   ASAAS_ENV      → "sandbox" ou "production" (default: sandbox)
class AsaasService
  SANDBOX_URL    = "https://sandbox.asaas.com/api/v3".freeze
  PRODUCTION_URL = "https://api.asaas.com/v3".freeze

  class AsaasError < StandardError; end

  def initialize
    @api_key  = ENV.fetch("ASAAS_API_KEY") { raise AsaasError, "ASAAS_API_KEY não configurada" }
    @base_url = ENV["ASAAS_ENV"] == "production" ? PRODUCTION_URL : SANDBOX_URL
  end

  # ── Clientes ─────────────────────────────────────────────────────────────────

  # Cria ou recupera cliente pelo CPF/CNPJ.
  # Retorna o hash do cliente (com "id").
  def find_or_create_customer(company)
    cpf_cnpj = company.cnpj&.gsub(/\D/, "").presence

    # Tenta buscar pelo cpfCnpj primeiro
    if cpf_cnpj
      result = get("/customers", cpfCnpj: cpf_cnpj)
      existing = result["data"]&.first
      return existing if existing
    end

    post("/customers", {
      name:     company.name,
      email:    company.email.presence || company.owner&.email,
      cpfCnpj: cpf_cnpj,
      phone:    company.phone&.gsub(/\D/, "").presence,
      externalReference: "company_#{company.id}"
    }.compact)
  end

  # ── Assinaturas ───────────────────────────────────────────────────────────────

  # Cria assinatura recorrente mensal via PIX.
  # Retorna hash da assinatura (com "id" e "status").
  def create_subscription(customer_id:, plan:, company:)
    post("/subscriptions", {
      customer:         customer_id,
      billingType:      "UNDEFINED",
      value:            plan.price.to_f,
      nextDueDate:      Date.today.strftime("%Y-%m-%d"),
      cycle:            "MONTHLY",
      description:      "Assinatura Backstage — Plano #{plan.name}",
      externalReference: "company_#{company.id}_plan_#{plan.id}"
    })
  end

  # Cancela uma assinatura existente.
  def cancel_subscription(subscription_id)
    delete("/subscriptions/#{subscription_id}")
  end

  # Busca dados de uma assinatura.
  def get_subscription(subscription_id)
    get("/subscriptions/#{subscription_id}")
  end

  # Busca o link de pagamento (QR Code PIX) da cobrança mais recente de uma assinatura.
  def pending_payment(subscription_id)
    result = get("/payments", subscription: subscription_id, status: "PENDING")
    result["data"]&.first
  end

  # ── HTTP helpers ─────────────────────────────────────────────────────────────

  def get(path, params = {})
    uri = URI("#{@base_url}#{path}")
    uri.query = URI.encode_www_form(params) if params.any?
    request(Net::HTTP::Get.new(uri))
  end

  private

  def post(path, body)
    uri = URI("#{@base_url}#{path}")
    req = Net::HTTP::Post.new(uri)
    req.body = body.to_json
    request(req)
  end

  def delete(path)
    uri = URI("#{@base_url}#{path}")
    request(Net::HTTP::Delete.new(uri))
  end

  def request(req)
    req["access_token"] = @api_key
    req["Content-Type"]  = "application/json"
    req["Accept"]        = "application/json"

    uri = req.uri
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.read_timeout = 15
      response = http.request(req)
      body = JSON.parse(response.body)

      unless response.is_a?(Net::HTTPSuccess)
        errors = body["errors"]&.map { |e| e["description"] }&.join(", ")
        raise AsaasError, errors.presence || "Erro #{response.code} na API do Asaas"
      end

      body
    end
  end
end
