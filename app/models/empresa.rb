class Empresa < ApplicationRecord
  has_one_attached :logo

  has_many :empresa_users, dependent: :destroy
  has_many :users, through: :empresa_users
  has_many :events, dependent: :nullify

  validates :name, presence: true
  validates :cnpj, uniqueness: { allow_blank: true },
                   format: { with: /\A\d{2}\.\d{3}\.\d{3}\/\d{4}-\d{2}\z/, message: "formato inválido (XX.XXX.XXX/XXXX-XX)", allow_blank: true }

  def owner
    empresa_users.find_by(role: "owner")&.user
  end

  def cnpj_formatted
    cnpj
  end
end
