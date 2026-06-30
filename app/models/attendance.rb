class Attendance < ApplicationRecord
  belongs_to :user
  belongs_to :event
  belongs_to :team, optional: true
  belongs_to :checked_in_by,  class_name: "User", optional: true
  belongs_to :checked_out_by, class_name: "User", foreign_key: :checked_out_by_id, optional: true

  validates :user_id, uniqueness: { scope: [:event_id, :checked_in_date], message: "já registrou presença neste dia" }
  validates :checked_in_at,   presence: true
  validates :checked_in_date, presence: true

  before_validation :set_checked_in_date

  private

  def set_checked_in_date
    self.checked_in_date ||= checked_in_at&.to_date || Date.today
  end
end
