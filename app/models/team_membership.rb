class TeamMembership < ApplicationRecord
  belongs_to :team
  belongs_to :user

  before_create :generate_credential_code

  # credential_code já armazena o código completo: "BOO-XXXXXXXX"
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
