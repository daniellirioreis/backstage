class Shift < ApplicationRecord
  belongs_to :user
  belongs_to :sector

  validates :date, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true
  validate :end_time_after_start_time
  validate :no_schedule_conflict

  private

  def end_time_after_start_time
    return if start_time.blank? || end_time.blank?
    errors.add(:end_time, :after_start_time) if end_time <= start_time
  end

  def no_schedule_conflict
    return if user_id.blank? || date.blank? || start_time.blank? || end_time.blank?

    conflict = Shift.where(user_id: user_id, date: date)
                    .where.not(id: id)
                    .where("start_time < ? AND end_time > ?", end_time, start_time)

    errors.add(:base, :schedule_conflict) if conflict.exists?
  end
end
