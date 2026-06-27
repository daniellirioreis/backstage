class Role < ApplicationRecord
  has_many :users, dependent: :nullify
  has_many :permissions, dependent: :destroy

  validates :name, presence: true, uniqueness: true

  def can?(resource, action)
    permissions.exists?(resource: resource.to_s, action: action.to_s)
  end
end
