class AddInvitationsPermissionToAllRoles < ActiveRecord::Migration[7.1]
  def up
    Role.find_each do |role|
      next if role.collaborator?
      %w[index create].each do |action|
        Permission.find_or_create_by!(role: role, resource: "invitations", action: action)
      end
    end
  end

  def down
    Permission.where(resource: "invitations").destroy_all
  end
end
