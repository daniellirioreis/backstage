puts "→ Criando usuário admin..."

admin_role = Role.find_by!(name: "admin")

admin = User.find_or_initialize_by(email: "admin@backstage.com")

if admin.new_record?
  admin.name     = "Admin"
  admin.phone    = "11999999999"
  admin.role     = admin_role
  admin.password = "senha123"
  admin.cpf      = "52998224725"
  admin.save!
  puts "   Admin criado: admin@backstage.com / senha123"
else
  admin.update_columns(role_id: admin_role.id)
  puts "   Admin já existe, role atualizado."
end
