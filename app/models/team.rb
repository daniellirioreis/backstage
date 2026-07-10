class Team < ApplicationRecord
  belongs_to :sector
  belongs_to :coordinator, class_name: "User", optional: true
  has_one :event, through: :sector
  has_many :team_memberships, dependent: :destroy
  has_many :users, through: :team_memberships
  has_many :shifts, dependent: :destroy
  has_many :attendances, dependent: :nullify

  accepts_nested_attributes_for :team_memberships,
                                reject_if: proc { |a| a["user_id"].blank? },
                                allow_destroy: true

  # Sincroniza a membership do coordenador sempre que coordinator_id mudar
  after_save :sync_coordinator_membership, if: :saved_change_to_coordinator_id?

  attr_accessor :skip_member_uniqueness_check

  validates :name, presence: true
  validate :regular_members_unique_per_event, unless: :skip_member_uniqueness_check

  private

  # Cria/atualiza/remove a TeamMembership com role :coordinator
  def sync_coordinator_membership
    old_id, new_id = saved_change_to_coordinator_id

    # Remove membership de coordenador do antigo coordenador
    if old_id.present?
      team_memberships.where(user_id: old_id, role: :coordinator).destroy_all
    end

    # Cria ou promove membership do novo coordenador
    if new_id.present?
      tm = team_memberships.find_or_initialize_by(user_id: new_id)
      tm.role = :coordinator
      tm.save!
    end
  end

  # Apenas membros regulares precisam ser únicos por evento.
  # Coordenadores são sempre isentos: podem atuar em múltiplas equipes.
  def regular_members_unique_per_event
    return unless sector.present?

    # IDs dos membros desta equipe, excluindo:
    #   • linhas marcadas para remoção
    #   • o coordenador desta equipe (independente do role salvo no DB)
    my_member_ids = team_memberships
      .reject(&:marked_for_destruction?)
      .select(&:member?)
      .map(&:user_id)
      .compact
      .reject { |uid| uid == coordinator_id }

    return if my_member_ids.empty?

    other_memberships = TeamMembership
      .joins(team: :sector)
      .where(sectors: { event_id: sector.event_id })
      .where(role: :member)
      .where.not(team_id: id)
      .includes(:user, team: :sector)

    conflict_map = other_memberships.each_with_object({}) do |tm, h|
      # Ignora se o usuário é coordenador da outra equipe
      # (cobre dados antigos onde o role ainda não foi corrigido para :coordinator)
      next if tm.team.coordinator_id == tm.user_id
      h[tm.user_id] = tm
    end

    duplicates = my_member_ids & conflict_map.keys
    duplicates.each do |uid|
      tm   = conflict_map[uid]
      name = tm.user.name
      errors.add(:base, "#{name} já está na equipe \"#{tm.team.name}\" (#{tm.team.sector.name})")
    end
  end
end
