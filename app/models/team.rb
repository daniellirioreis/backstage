class Team < ApplicationRecord
  belongs_to :sector
  has_one :event, through: :sector
  has_many :team_memberships, dependent: :destroy
  has_many :users, through: :team_memberships

  validates :name, presence: true
end
