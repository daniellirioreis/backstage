class AddCollaboratorToRoles < ActiveRecord::Migration[7.1]
  def change
    add_column :roles, :collaborator, :boolean, default: false, null: false
  end
end
