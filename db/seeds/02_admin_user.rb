puts "→ Criando usuário admin..."

admin_role = Role.find_by!(name: "admin")

# Busca por e-mail primeiro; se não achar, busca por CPF (cobre inconsistência no banco)
admin = User.find_by(email: "daniellirioreis@gmail.com") ||
        User.find_by(cpf: "07816691629")

if admin
  admin.update_columns(email: "daniellirioreis@gmail.com", role_id: admin_role.id)
  puts "   Admin já existe, dados corrigidos."
else
  admin = User.new(
    name:     "Admin",
    email:    "daniellirioreis@gmail.com",
    phone:    "31984143978",
    role:     admin_role,
    password: "120188",
    cpf:      "07816691629"
  )
  admin.save!
  puts "   Admin criado: daniellirioreis@gmail.com / 120188 / CPF: #{admin.cpf}"
end
