class AssignCoordinatorRoleToTeamCoordinators < ActiveRecord::Migration[7.1]
  def up
    coordinator_role = Role.find_by(id: 3)
    unless coordinator_role
      puts "Role id=3 não encontrado, migration ignorada."
      return
    end

    coordinator_ids = Team.where.not(coordinator_id: nil).pluck(:coordinator_id).uniq
    updated = User.where(id: coordinator_ids).update_all(role_id: 3)
    puts "#{updated} colaborador(es) atribuídos ao papel '#{coordinator_role.name}'."
  end

  def down
    # Irreversível — não há como saber o papel anterior de cada usuário
    raise ActiveRecord::IrreversibleMigration
  end
end
