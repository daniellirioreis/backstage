class EmpresaUser < ApplicationRecord
  belongs_to :empresa
  belongs_to :user

  ROLES = %w[owner manager operator].freeze

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :empresa_id, message: "já pertence a esta empresa" }

  def role_label
    { "owner" => "Dono", "manager" => "Gerente", "operator" => "Operador" }[role] || role
  end
end
