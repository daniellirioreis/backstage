class DailyCredential < ApplicationRecord
  belongs_to :team_membership

  has_one :user, through: :team_membership
  has_one :team, through: :team_membership

  before_create :generate_code

  def full_credential_code
    credential_code
  end

  private

  def generate_code
    event_code = team_membership.team&.sector&.event&.code.presence || "EVT"
    loop do
      raw = SecureRandom.alphanumeric(8).upcase
      self.credential_code = "#{event_code.upcase}-#{raw}"
      break unless DailyCredential.exists?(credential_code: credential_code)
    end
  end
end
