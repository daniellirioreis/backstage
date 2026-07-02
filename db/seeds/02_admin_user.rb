puts "→ Criando usuário admin..."

admin_role = Role.find_by!(name: "admin")

# Busca por e-mail primeiro; se não achar, busca por CPF (cobre inconsistência no banco)
admin = User.find_by(email: "admin@backstage.com") ||
        User.find_by(cpf: "52998224725")

if admin
  admin.update_columns(email: "admin@backstage.com", role_id: admin_role.id)
  puts "   Admin já existe, dados corrigidos."
else
  admin = User.new(
    name:     "Admin",
    email:    "admin@backstage.com",
    phone:    "11999999999",
    role:     admin_role,
    password: "senha123",
    cpf:      "52998224725"
  )
  admin.save!
  puts "   Admin criado: admin@backstage.com / senha123"
end
