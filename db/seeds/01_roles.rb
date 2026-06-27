puts "→ Criando perfis e permissões..."

admin_role = Role.find_or_create_by!(name: "admin")

Permission::RESOURCES.each do |resource|
  Permission::ACTIONS.each do |action|
    Permission.find_or_create_by!(role: admin_role, resource: resource, action: action)
  end
end

Role.find_or_create_by!(name: "colaborador")

puts "   Perfis: #{Role.count} | Permissões: #{Permission.count}"
