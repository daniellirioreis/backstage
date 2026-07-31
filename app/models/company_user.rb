class CompanyUser < ApplicationRecord
  belongs_to :company
  belongs_to :user

  ROLES = %w[
    owner manager operator collaborator
    production_director executive_producer producer event_analyst
    event_coordinator operations_coordinator sector_coordinator
  ].freeze

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :company_id, message: "já pertence a esta empresa" }

  def role_label
    I18n.t("company_user.roles.#{role}", default: role.humanize)
  end
end
