puts "→ Criando empresa..."

company = Company.find_or_initialize_by(name: "Produtora Horizonte")
if company.new_record?
  company.save!
  puts "   Empresa criada: #{company.name} (id=#{company.id})"
else
  puts "   Empresa já existe: #{company.name} (id=#{company.id})"
end
