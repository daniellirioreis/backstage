class User < ApplicationRecord
  devise :database_authenticatable,
         :recoverable,
         :rememberable,
         :validatable

  belongs_to :role, optional: true

  delegate :can?, to: :role, allow_nil: true

  def admin?
    role&.name == "admin"
  end

  validates :name, presence: true
  validates :cpf, presence: true, uniqueness: true,
                  format: { with: /\A\d{11}\z/, message: :invalid_cpf }
  validates :phone, presence: true
end
