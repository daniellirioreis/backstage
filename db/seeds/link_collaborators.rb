company = Company.find(1)

users_without_company = User.where.not(
  id: CompanyUser.select(:user_id)
)

count = 0
users_without_company.each do |user|
  CompanyUser.create!(
    company: company,
    user:    user,
    role:    "collaborator"
  )
  count += 1
rescue ActiveRecord::RecordInvalid => e
  puts "  AVISO: #{user.name} — #{e.message}"
end

puts "#{count} colaboradores vinculados à empresa #{company.name} (id: #{company.id})"
