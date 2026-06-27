class Event < ApplicationRecord
  has_many :sectors, dependent: :destroy
  has_many :teams, through: :sectors

  enum :status, { draft: "draft", active: "active", closed: "closed" }, validate: true

  validates :name, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validate :end_date_after_start_date

  private

  def end_date_after_start_date
    return if start_date.blank? || end_date.blank?
    errors.add(:end_date, :after_start_date) if end_date < start_date
  end
end
