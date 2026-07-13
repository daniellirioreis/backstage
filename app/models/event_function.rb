class EventFunction < ApplicationRecord
  belongs_to :event, optional: true
  has_many :team_memberships, dependent: :nullify
  has_many :sector_functions, dependent: :destroy

  scope :catalog, -> { where(event_id: nil) }
  scope :for_event, ->(event) { where(event: event) }

  validates :name,        presence: true
  validates :hourly_rate, presence: true, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :name, uniqueness: { scope: :event_id, message: "já existe neste evento" },
                  unless: -> { event_id.nil? && event&.new_record? }

  def catalog?
    event_id.nil?
  end

  def to_s
    name
  end

  def hourly_rate_formatted
    "R$ #{format('%.2f', hourly_rate)}/h"
  end
end
