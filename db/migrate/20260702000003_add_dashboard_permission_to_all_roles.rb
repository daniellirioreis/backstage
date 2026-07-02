class AddDashboardPermissionToAllRoles < ActiveRecord::Migration[7.1]
  def up
    Role.find_each do |role|
      next if role.collaborator?
      Permission.find_or_create_by!(role: role, resource: "dashboard", action: "index")
    end
  end

  def down
    Permission.where(resource: "dashboard", action: "index").destroy_all
  end
end
