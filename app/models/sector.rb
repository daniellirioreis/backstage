class Sector < ApplicationRecord
  belongs_to :team
  has_many :shifts, dependent: :destroy

  validates :name, presence: true
end
