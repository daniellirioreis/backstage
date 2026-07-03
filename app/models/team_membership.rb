class TeamMembership < ApplicationRecord
  belongs_to :team
  belongs_to :user
  belongs_to :event_function, optional: true

  enum :role, { member: 0, coordinator: 1 }, default: :member

  before_create :generate_credential_code

  def full_credential_code
    credential_code
  end

  private

  def generate_credential_code
    event_code = team&.sector&.event&.code.presence || "EVT"
    loop do
      raw = SecureRandom.alphanumeric(8).upcase
      self.credential_code = "#{event_code.upcase}-#{raw}"
      break unless TeamMembership.exists?(credential_code: credential_code)
    end
  end
end
