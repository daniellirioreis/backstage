# Cria perfil admin com todas as permissões
admin_role = Role.find_or_create_by!(name: "admin")

Permission::RESOURCES.each do |resource|
  Permission::ACTIONS.each do |action|
    Permission.find_or_create_by!(role: admin_role, resource: resource, action: action)
  end
end

# Cria usuário admin inicial
User.find_or_create_by!(email: "admin@backstage.com") do |u|
  u.name     = "Admin"
  u.cpf      = "00000000000"
  u.phone    = "11999999999"
  u.password = "senha123"
  u.role     = admin_role
end

puts "Seed concluído: perfil admin + usuário admin criados."
