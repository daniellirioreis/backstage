class EventDay < ApplicationRecord
  belongs_to :event

  validates :date,  presence: true
  validates :hours, presence: true,
                    numericality: { greater_than: 0, less_than_or_equal_to: 24 }
  validates :date, uniqueness: { scope: :event_id, message: "já cadastrada para este evento" }

  scope :ordered, -> { order(:date) }
end
