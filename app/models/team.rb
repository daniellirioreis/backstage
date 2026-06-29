class Team < ApplicationRecord
  belongs_to :sector
  belongs_to :coordinator, class_name: "User", optional: true
  has_one :event, through: :sector
  has_many :team_memberships, dependent: :destroy
  has_many :users, through: :team_memberships

  accepts_nested_attributes_for :team_memberships,
                                reject_if: proc { |a| a["user_id"].blank? },
                                allow_destroy: true

  before_save :generate_coordinator_credential_code, if: :coordinator_id_changed?

  # coordinator_credential_code já armazena o código completo: "BOO-XXXXXXXX"
  def coordinator_full_credential_code
    coordinator_credential_code
  end

  validates :name, presence: true
  validate :coordinator_unique_per_event
  validate :coordinator_not_in_collaborators
  validate :collaborators_unique_per_event

  private

  def coordinator_not_in_collaborators
    return unless coordinator_id.present?
    if active_membership_user_ids.include?(coordinator_id)
      errors.add(:coordinator_id, "não pode ser também um colaborador da equipe")
    end
  end

  def collaborators_unique_per_event
    return unless sector.present?

    other_memberships = TeamMembership.joins(team: :sector)
                                      .where(sectors: { event_id: sector.event_id })
                                      .where.not(team_id: id)
                                      .includes(:user, team: :sector)

    conflict_map = other_memberships.each_with_object({}) do |tm, h|
      h[tm.user_id] = tm
    end

    duplicates = active_membership_user_ids & conflict_map.keys
    duplicates.each do |uid|
      tm   = conflict_map[uid]
      name = tm.user.name
      errors.add(:base, "#{name} já está na equipe \"#{tm.team.name}\" (#{tm.team.sector.name})")
    end
  end

  # Retorna IDs dos membros que NÃO estão marcados para remoção
  def active_membership_user_ids
    team_memberships.reject(&:marked_for_destruction?).map(&:user_id)
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
