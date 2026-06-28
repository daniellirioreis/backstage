class Attendance < ApplicationRecord
  belongs_to :user
  belongs_to :event
  belongs_to :team, optional: true
  belongs_to :checked_in_by, class_name: "User", optional: true

  validates :user_id, uniqueness: { scope: :event_id, message: "já registrou presença neste evento" }
  validates :checked_in_at, presence: true
end
