class Vehicle < ApplicationRecord
  validates :model, presence: true
  validates :license_plate, presence: true, uniqueness: true
end
