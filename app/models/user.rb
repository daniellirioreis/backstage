class User < ApplicationRecord
  devise :database_authenticatable,
         :recoverable,
         :rememberable,
         :validatable

  belongs_to :role
  has_many :team_memberships, dependent: :destroy
  has_many :teams, through: :team_memberships
  has_many :empresa_users, dependent: :destroy
  has_many :empresas, through: :empresa_users
  has_one_attached :avatar
  attr_accessor :remove_avatar
  before_save { avatar.purge if remove_avatar == "1" }

  delegate :can?, to: :role, allow_nil: true

  before_validation :strip_cpf

  def admin?
    role&.name == "admin"
  end

  def empresa_role_for(empresa)
    empresa_users.find_by(empresa: empresa)&.role
  end

  validates :name, presence: true
  validates :cpf, presence: true, uniqueness: true,
                  format: { with: /\A\d{11}\z/, message: :invalid_cpf }
  validate :cpf_check_digits, if: -> { cpf.present? && cpf.match?(/\A\d{11}\z/) }
  validates :phone, presence: true

  private

  def strip_cpf
    self.cpf = cpf.to_s.gsub(/\D/, "")
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
