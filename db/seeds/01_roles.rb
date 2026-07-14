puts "→ Criando perfis e permissões..."

admin_role = Role.find_or_create_by!(name: "admin")

Permission::RESOURCES.each do |resource|
  all_actions = Permission::ACTIONS + (Permission::EXTRA_ACTIONS[resource] || [])
  all_actions.each do |action|
    Permission.find_or_create_by!(role: admin_role, resource: resource, action: action)
  end
end

colab = Role.find_or_create_by!(name: "colaborador")

# Perfil coordenador: acesso operacional focado na equipe
coord = Role.find_or_create_by!(name: "coordenador")
[
  %w[teams    show],
  %w[teams    panel],
  %w[teams    coordinator],
  %w[teams    credentials],
  %w[teams    manage_members],  # pode adicionar/importar colaboradores na equipe
  %w[attendances index],
  %w[attendances scan],
  %w[attendances checkout],
  %w[users    my_schedule],
].each do |resource, action|
  Permission.find_or_create_by!(role: coord, resource: resource, action: action)
end

# Perfil gerente: acesso amplo a eventos, relatórios e gestão de equipes
gerente = Role.find_or_create_by!(name: "gerente")
[
  # Eventos
  %w[events      index],
  %w[events      show],
  %w[events      create],
  %w[events      update],
  # Setores
  %w[sectors     index],
  %w[sectors     show],
  %w[sectors     create],
  %w[sectors     update],
  # Equipes
  %w[teams       index],
  %w[teams       show],
  %w[teams       create],
  %w[teams       update],
  %w[teams       panel],
  %w[teams       coordinator],
  %w[teams       credentials],
  %w[teams       manage_members],
  %w[teams       quick_add_member],
  # Escalas
  %w[shifts      index],
  %w[shifts      show],
  %w[shifts      create],
  %w[shifts      update],
  %w[shifts      destroy],
  %w[shifts      timeline],
  %w[shifts      print],
  # Colaboradores
  %w[users       index],
  %w[users       show],
  %w[users       create],
  %w[users       update],
  %w[users       my_schedule],
  # Presenças
  %w[attendances index],
  %w[attendances scan],
  %w[attendances checkout],
  # Veículos
  %w[vehicles    index],
  %w[vehicles    show],
  %w[vehicles    create],
  %w[vehicles    update],
  # Relatórios
  %w[reports     closing],
  %w[reports     manage_payments],
  %w[reports     finalize_closing],
  %w[reports     reopen_closing],
  %w[reports     attendance_report],
  %w[reports     absences_report],
  %w[reports     hours_worked_report],
  %w[reports     sector_summary_report],
  # Dashboard
  %w[dashboard   index],
  # Credenciais
  %w[badge_configs show],
  %w[badge_configs update],
  # Convites
  %w[invitations index],
  %w[invitations create],
].each do |resource, action|
  Permission.find_or_create_by!(role: gerente, resource: resource, action: action)
end

puts "   Perfis: #{Role.count} | Permissões: #{Permission.count}"
