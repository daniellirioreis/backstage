puts "→ Criando usuário admin..."

admin_role = Role.find_by!(name: "admin")

User.find_or_create_by!(email: "admin@backstage.com") do |u|
  u.name     = "Admin"
  u.cpf      = "52998224725"
  u.phone    = "11999999999"
  u.password = "senha123"
  u.role     = admin_role
end

puts "   Admin: admin@backstage.com / senha123"
