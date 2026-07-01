class SetCollaboratorFlagOnColaboradorRole < ActiveRecord::Migration[7.1]
  def up
    Role.where(name: "colaborador").update_all(collaborator: true)
  end

  def down
    Role.where(name: "colaborador").update_all(collaborator: false)
  end
end
