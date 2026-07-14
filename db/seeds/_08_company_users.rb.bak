puts "→ Associando colaboradores à empresa..."

company = Company.first

unless company
  puts "   AVISO: Empresa id=1 não encontrada, pulando."
else
  collaborator_role = Role.find_by!(name: "colaborador")

  User.where(role: collaborator_role).find_each do |user|
    CompanyUser.find_or_create_by!(company: company, user: user) do |cu|
      cu.role = "operator"
    end
  rescue ActiveRecord::RecordInvalid => e
    puts "  AVISO: #{user.name} — #{e.message}"
  end

  puts "   Membros da empresa '#{company.name}': #{company.company_users.count}"
end
