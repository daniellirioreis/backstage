puts "→ Criando perfis e permissões..."

admin_role = Role.find_or_create_by!(name: "admin")

Permission::RESOURCES.each do |resource|
  all_actions = Permission::ACTIONS + (Permission::EXTRA_ACTIONS[resource] || [])
  all_actions.each do |action|
    Permission.find_or_create_by!(role: admin_role, resource: resource, action: action)
  end
end

colab = Role.find_or_create_by!(name: "colaborador")
colab.update!(collaborator: true) unless colab.collaborator?

# Perfil coordenador: acesso operacional focado na equipe
coord = Role.find_or_create_by!(name: "coordenador")
[
  %w[teams    show],
  %w[teams    panel],
  %w[teams    credentials],
  %w[teams    manage_members],  # pode adicionar/importar colaboradores na equipe
  %w[attendances index],
  %w[attendances scan],
  %w[attendances checkout],
  %w[users    my_schedule],
].each do |resource, action|
  Permission.find_or_create_by!(role: coord, resource: resource, action: action)
end

puts "   Perfis: #{Role.count} | Permissões: #{Permission.count}"
