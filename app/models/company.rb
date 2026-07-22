class Company < ApplicationRecord
  has_one_attached :logo

  belongs_to :plan, optional: true

  has_many :company_users, dependent: :destroy
  has_many :users, through: :company_users
  has_many :events, dependent: :nullify

  validates :name, presence: true
  validates :cnpj, uniqueness: { allow_blank: true, message: "já está cadastrado" },
                   format: { with: /\A\d{2}\.\d{3}\.\d{3}\/\d{4}-\d{2}\z/, message: "formato inválido (XX.XXX.XXX/XXXX-XX)", allow_blank: true }
  validate :cnpj_digits_valid, if: -> { cnpj.present? }

  # ── Uso atual ────────────────────────────────────────────────────────────────
  def current_events_count  = events.count
  def current_members_count = company_users.count

  # ── Limites do plano (nil = sem plano = ilimitado) ───────────────────────────
  def events_limit  = plan&.events_limit
  def members_limit = plan&.members_limit

  def can_add_event?
    return true if events_limit.nil?
    current_events_count < events_limit
  end

  def can_add_member?
    return true if members_limit.nil?
    current_members_count < members_limit
  end

  def owner
    company_users.find_by(role: "owner")&.user
  end

  # ── Assinatura ───────────────────────────────────────────────────────────────
  SUBSCRIPTION_STATUSES = %w[inactive pending active overdue cancelled].freeze

  def subscription_active?  = subscription_status == "active"
  def subscription_pending? = subscription_status == "pending"
  def subscription_overdue? = subscription_status == "overdue"

  def cnpj_digits_valid
    digits = cnpj.to_s.gsub(/\D/, "")
    return if digits.length != 14
    return errors.add(:cnpj, "inválido") if digits.chars.uniq.length == 1

    calc = ->(d, start_weight) {
      sum, w = 0, start_weight
      d.each_char { |c| sum += c.to_i * w; w = w == 2 ? 9 : w - 1 }
      r = sum % 11
      r < 2 ? 0 : 11 - r
    }

    d1 = calc.call(digits[0..11], 5)
    d2 = calc.call(digits[0..12], 6)

    errors.add(:cnpj, "inválido") unless d1 == digits[12].to_i && d2 == digits[13].to_i
  end

  def subscription_status_label
    { "inactive" => "Sem assinatura", "pending" => "Aguardando pagamento",
      "active"   => "Ativo",          "overdue"  => "Em atraso",
      "cancelled" => "Cancelado" }[subscription_status] || subscription_status
  end
end
