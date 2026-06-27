class Sector < ApplicationRecord
  belongs_to :event
  has_many :teams, dependent: :destroy
  has_many :shifts, dependent: :destroy

  validates :name, presence: true
end
