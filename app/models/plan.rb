class Plan < ApplicationRecord
  has_many :companies, dependent: :nullify

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :events_limit,  numericality: { only_integer: true, greater_than: 0, allow_nil: true }
  validates :members_limit, numericality: { only_integer: true, greater_than: 0, allow_nil: true }

  def unlimited_events?  = events_limit.nil?
  def unlimited_members? = members_limit.nil?

  def events_limit_label  = unlimited_events?  ? "Ilimitado" : events_limit.to_s
  def members_limit_label = unlimited_members? ? "Ilimitado" : members_limit.to_s
end
