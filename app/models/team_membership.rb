class TeamMembership < ApplicationRecord
  belongs_to :team
  belongs_to :user
  belongs_to :event_function, optional: true
  belongs_to :replaced_user, class_name: "User", optional: true

  enum :role, { member: 0, coordinator: 1 }, default: :member

  validates :user_id, uniqueness: { scope: :team_id, message: "já está nesta equipe" }
  validate  :not_already_in_event

  before_create :generate_credential_code

  def full_credential_code
    credential_code
  end

  private

  def not_already_in_event
    return if user_id.blank? || team_id.blank?

    event_id = team&.sector&.event_id
    return unless event_id

    conflict = TeamMembership
      .joins(team: :sector)
      .where(user_id: user_id, sectors: { event_id: event_id })
      .where.not(team_id: team_id)
      .first

    return unless conflict

    errors.add(:user, "já está escalado(a) na equipe \"#{conflict.team.name}\" neste evento")
  end

  def generate_credential_code
    event_code = team&.sector&.event&.code.presence || "EVT"
    loop do
      raw = SecureRandom.alphanumeric(8).upcase
      self.credential_code = "#{event_code.upcase}-#{raw}"
      break unless TeamMembership.exists?(credential_code: credential_code)
    end
  end
end
