class CompanyUser < ApplicationRecord
  belongs_to :company
  belongs_to :user

  ROLES = %w[owner manager operator].freeze

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :company_id, message: "já pertence a esta empresa" }

  def role_label
    I18n.t("company_user.roles.#{role}", default: role.humanize)
  end
end
