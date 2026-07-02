class Company < ApplicationRecord
  has_one_attached :logo

  belongs_to :plan, optional: true

  has_many :company_users, dependent: :destroy
  has_many :users, through: :company_users
  has_many :events, dependent: :nullify

  validates :name, presence: true
  validates :cnpj, uniqueness: { allow_blank: true },
                   format: { with: /\A\d{2}\.\d{3}\.\d{3}\/\d{4}-\d{2}\z/, message: "formato inválido (XX.XXX.XXX/XXXX-XX)", allow_blank: true }

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
end
