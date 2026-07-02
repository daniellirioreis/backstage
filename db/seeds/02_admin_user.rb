puts "→ Criando usuário admin..."

admin_role = Role.find_by!(name: "admin")

admin = User.find_or_initialize_by(email: "admin@backstage.com")
admin.name  = "Admin"
admin.phone = "11999999999"
admin.role  = admin_role
admin.password = "senha123" if admin.new_record?
admin.cpf      = "52998224725" if admin.cpf.blank?
admin.save!

puts "   Admin: admin@backstage.com / senha123"
