class AddRoleToTeamMemberships < ActiveRecord::Migration[7.1]
  def up
    add_column :team_memberships, :role, :integer, default: 0, null: false

    # Migra coordenadores existentes: cria TeamMembership com role=coordinator
    # para cada Team que tem coordinator_id mas o coordenador ainda não é membro
    Team.where.not(coordinator_id: nil).find_each do |team|
      existing = TeamMembership.find_by(team_id: team.id, user_id: team.coordinator_id)
      if existing
        existing.update_column(:role, 1) # coordinator
      else
        # Gera credential_code manualmente (sem callbacks)
        event_code = Sector.joins(:event).find_by(id: team.sector_id)
                           &.event&.code.presence || "EVT"
        loop do
          raw  = SecureRandom.alphanumeric(8).upcase
          code = "#{event_code.upcase}-#{raw}"
          next if TeamMembership.exists?(credential_code: code)
          TeamMembership.insert({
            team_id:         team.id,
            user_id:         team.coordinator_id,
            role:            1,
            credential_code: code,
            created_at:      Time.current,
            updated_at:      Time.current
          })
          break
        end
      end
    end
  end

  def down
    remove_column :team_memberships, :role
  end
end
