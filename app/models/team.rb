class Team < ApplicationRecord
  belongs_to :sector
  belongs_to :coordinator, class_name: "User", optional: true
  has_one :event, through: :sector
  has_many :team_memberships, dependent: :destroy
  has_many :users, through: :team_memberships

  before_save :generate_coordinator_credential_code, if: :coordinator_id_changed?

  # coordinator_credential_code já armazena o código completo: "BOO-XXXXXXXX"
  def coordinator_full_credential_code
    coordinator_credential_code
  end

  validates :name, presence: true
  validate :must_have_at_least_one_user
  validate :coordinator_unique_per_event
  validate :coordinator_not_in_collaborators
  validate :collaborators_unique_per_event

  private

  def must_have_at_least_one_user
    errors.add(:base, "A equipe deve ter pelo menos 1 colaborador") if users.size == 0
  end

  def coordinator_not_in_collaborators
    return unless coordinator_id.present?
    if users.map(&:id).include?(coordinator_id)
      errors.add(:coordinator_id, "não pode ser também um colaborador da equipe")
    end
  end

  def collaborators_unique_per_event
    return unless sector.present?

    other_team_user_ids = TeamMembership.joins(team: :sector)
                                        .where(sectors: { event_id: sector.event_id })
                                        .where.not(team_id: id)
                                        .pluck(:user_id)

    duplicates = users.map(&:id) & other_team_user_ids
    if duplicates.any?
      names = User.where(id: duplicates).pluck(:name).join(", ")
      errors.add(:base, "#{names} já #{duplicates.size == 1 ? 'está' : 'estão'} em outra equipe neste evento")
    end
  end

  def generate_coordinator_credential_code
    return if coordinator_id.blank?
    event_code = sector&.event&.code.presence || "EVT"
    loop do
      raw = SecureRandom.alphanumeric(8).upcase
      self.coordinator_credential_code = "#{event_code.upcase}-#{raw}"
      break unless Team.exists?(coordinator_credential_code: coordinator_credential_code)
    end
  end

  def coordinator_unique_per_event
    return unless coordinator_id.present? && sector.present?

    conflict = Team.joins(:sector)
                   .where(sectors: { event_id: sector.event_id })
                   .where(coordinator_id: coordinator_id)
                   .where.not(id: id)
                   .exists?

    errors.add(:coordinator_id, "já é coordenador de outra equipe neste evento") if conflict
  end
end
