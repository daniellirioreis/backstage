class Permission < ApplicationRecord
  belongs_to :role

  validates :resource, presence: true
  validates :action, presence: true
  validates :action, uniqueness: { scope: [ :role_id, :resource ] }

  RESOURCES = %w[users roles events teams sectors shifts vehicles badge_configs attendances reports].freeze
  ACTIONS   = %w[index show create update destroy].freeze

  # Ações extras por recurso (além das padrão)
  EXTRA_ACTIONS = {
    "shifts"      => %w[timeline print],
    "events"      => %w[print],
    "users"       => %w[my_schedule],
    "attendances" => %w[scan],
    "reports"     => %w[fechamento]
  }.freeze
end
