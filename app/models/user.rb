class User < ApplicationRecord
  devise :database_authenticatable,
         :recoverable,
         :rememberable,
         :validatable

  belongs_to :role
  has_many :team_memberships, dependent: :destroy
  has_many :teams, through: :team_memberships
  has_many :payments, dependent: :destroy
  has_many :company_users, dependent: :destroy
  has_many :companies, through: :company_users
  has_one_attached :avatar
  attr_accessor :remove_avatar, :skip_required_validations
  before_save { avatar.purge if remove_avatar == "1" }

  delegate :can?, to: :role, allow_nil: true

  before_validation :strip_cpf

  def admin?
    role&.name == "admin"
  end

  def coordinator?
    role&.name == "coordenador"
  end

  def formatted_cpf
    return "—" if cpf.blank?
    cpf.gsub(/(\d{3})(\d{3})(\d{3})(\d{2})/, '\1.\2.\3-\4')
  end

  def company_role_for(company)
    company_users.find_by(company: company)&.role
  end

  # ── Invitation helpers ────────────────────────────────────────────────────
  def pending_invitation?
    invitation_token.present? && invitation_accepted_at.nil?
  end

  def onboarding_complete?
    return true if invitation_token.nil?   # usuário não veio por convite
    onboarding_completed_at.present?
  end

  def generate_invitation_token!
    token = SecureRandom.urlsafe_base64(24)
    update_column(:invitation_token, token)
    token
  end

  validates :name, presence: true
  validates :cpf, presence: true, uniqueness: true,
                  format: { with: /\A\d{11}\z/, message: :invalid_cpf },
                  unless: :skip_required_validations
  validate :cpf_check_digits, if: -> { cpf.present? && cpf.match?(/\A\d{11}\z/) }
  validates :phone, presence: true, unless: :skip_required_validations

  private

  def strip_cpf
    self.cpf = cpf.gsub(/\D/, "") if cpf.present?
  end

  def cpf_check_digits
    digits = cpf.chars.map(&:to_i)

    return errors.add(:cpf, :invalid_cpf) if digits.uniq.size == 1

    # Primeiro dígito verificador
    sum = 9.times.sum { |i| digits[i] * (10 - i) }
    rem = sum % 11
    first = rem < 2 ? 0 : 11 - rem
    return errors.add(:cpf, :invalid_cpf) if first != digits[9]

    # Segundo dígito verificador
    sum = 9.times.sum { |i| digits[i] * (11 - i) }
    sum += digits[9] * 2
    rem = sum % 11
    second = rem < 2 ? 0 : 11 - rem
    errors.add(:cpf, :invalid_cpf) if second != digits[10]
  end
end
