class Permission < ApplicationRecord
  belongs_to :role

  validates :resource, presence: true
  validates :action, presence: true
  validates :action, uniqueness: { scope: [ :role_id, :resource ] }

  RESOURCES = %w[users roles events teams sectors shifts vehicles].freeze
  ACTIONS   = %w[index show create update destroy].freeze
end
