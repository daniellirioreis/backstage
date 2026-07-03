class Permission < ApplicationRecord
  belongs_to :role

  validates :resource, presence: true
  validates :action, presence: true
  validates :action, uniqueness: { scope: [ :role_id, :resource ] }

  RESOURCES = %w[users roles events companies teams sectors shifts vehicles badge_configs attendances reports dashboard invitations].freeze
  ACTIONS   = %w[index show create update destroy].freeze

  # Ações extras por recurso (além das padrão)
  EXTRA_ACTIONS = {
    "shifts"      => %w[timeline print],
    "events"      => %w[print],
    "users"       => %w[my_schedule],
    "attendances" => %w[scan checkout],
    "reports"     => %w[closing manage_payments]
  }.freeze
end
