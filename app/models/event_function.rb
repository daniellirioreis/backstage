class EventFunction < ApplicationRecord
  belongs_to :event
  has_many :team_memberships, dependent: :nullify
  has_many :sector_functions, dependent: :destroy

  validates :name,        presence: true
  validates :hourly_rate, presence: true, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :name, uniqueness: { scope: :event_id, message: "já existe neste evento" }

  def to_s
    name
  end

  def hourly_rate_formatted
    "R$ #{format('%.2f', hourly_rate)}/h"
  end
end
