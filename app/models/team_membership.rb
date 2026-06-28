class TeamMembership < ApplicationRecord
  belongs_to :team
  belongs_to :user

  before_create :generate_credential_code

  def full_credential_code
    event_code = team&.sector&.event&.code.presence || "EVT"
    "#{event_code.upcase}-#{credential_code}"
  end

  private

  def generate_credential_code
    loop do
      self.credential_code = SecureRandom.alphanumeric(8).upcase
      break unless TeamMembership.exists?(credential_code: credential_code)
    end
  end
end
