class Team < ApplicationRecord
  belongs_to :event
  has_many :sectors, dependent: :destroy

  validates :name, presence: true
end
