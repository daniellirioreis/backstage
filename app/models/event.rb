class Event < ApplicationRecord
  has_many :sectors, dependent: :destroy
  has_many :teams, through: :sectors
  has_one :badge_config, dependent: :destroy
  has_many :event_functions, dependent: :destroy
  accepts_nested_attributes_for :event_functions,
                                reject_if: :all_blank,
                                allow_destroy: true

  enum :status, { draft: "draft", active: "active", closed: "closed" }, validate: true

  validates :name, presence: true
  validates :code, format: { with: /\A[A-Z0-9]{2,10}\z/i, message: "deve ter 2 a 10 letras/números" }, allow_blank: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validate :end_date_after_start_date

  private

  def end_date_after_start_date
    return if start_date.blank? || end_date.blank?
    errors.add(:end_date, :after_start_date) if end_date < start_date
  end
end
