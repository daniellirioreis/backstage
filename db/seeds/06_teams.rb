puts "→ Criando equipes e vínculos..."

event = Event.find_by!(name: "Boombay 2026")

def find_sector(name, event)
  Sector.find_by!(name: name, event: event)
end

def find_or_build_team(name, sector)
  t = Team.find_or_initialize_by(name: name, sector: sector)
  t.save(validate: false) if t.new_record?
  t
end

def add_members(team, cpfs)
  cpfs.each do |cpf|
    clean = cpf.gsub(/\D/, "")
    user  = User.find_by(cpf: clean)
    next unless user
    m = TeamMembership.find_or_initialize_by(team: team, user: user)
    m.save(validate: false) if m.new_record?
  end
end

# Carregadores
team = find_or_build_team("Equipe Carregadores", find_sector("Carregadores", event))
add_members(team, %w[111.138.456-86 113.701.166-16 189.397.846-00 045.558.156-88 096.798.656-57 127.266.296-95 103.537.666-07 018.641.666-06])

# Limpeza
team = find_or_build_team("Equipe Limpeza", find_sector("Limpeza", event))
add_members(team, %w[133.176.676-13 706.568.186-62 020.676.386-70 898.395.446-91 074.342.076-47 105.705.936-62 026.190.866-98 173.532.966-58 155.546.046-17 167.066.496-19 897.944.516-49 855.196.426-72 705.701.196-26 001.270.096-71 177.178.706-65 193.362.326-81 079.852.876-12 055.950.006-86 053.262.116-61 703.938.846-43 005.268.915-80])

# Guarda Volumes
team = find_or_build_team("Equipe Guarda Volumes", find_sector("Guarda Volumes", event))
add_members(team, %w[121.186.756-22 130.760.326-23 101.587.516-55 141.128.446-11])

# Guarda Volume Staff
team = find_or_build_team("Equipe Guarda Volume Staff", find_sector("Guarda Volume Staff", event))
add_members(team, %w[154.195.356-88])

# Lojinha
team = find_or_build_team("Equipe Lojinha", find_sector("Lojinha", event))
add_members(team, %w[162.735.106-01 087.004.756-61 113.976.276-11 704.232.906-65 123.242.986-43])

# Controle de Consumo
team = find_or_build_team("Equipe Controle de Consumo", find_sector("Controle de Consumo", event))
add_members(team, %w[023.157.276-00 133.441.326-60])

# Mega Fone
team = find_or_build_team("Equipe Mega Fone", find_sector("Mega Fone", event))
add_members(team, %w[141.085.536-83])

# Backstage
team = find_or_build_team("Equipe Backstage", find_sector("Backstage", event))
add_members(team, %w[125.432.956-07 143.799.776-76])

# Estoque Lojinha
team = find_or_build_team("Equipe Estoque Lojinha", find_sector("Estoque Lojinha", event))
add_members(team, %w[117.485.696-35])

# Caixa Ticket Social
team = find_or_build_team("Equipe Caixa Ticket Social", find_sector("Caixa Ticket Social", event))
add_members(team, %w[108.283.596-01 161.102.466-89 116.589.546-37 702.407.736-08 702.325.956-23 118.177.326-17])

# Troca de Alimento
team = find_or_build_team("Equipe Troca de Alimento", find_sector("Troca de Alimento", event))
add_members(team, %w[128.356.386-01 018.311.916-95 022.580.686-06 098.460.196-10 144.853.166-70])

# Bilheteria
team = find_or_build_team("Equipe Bilheteria", find_sector("Bilheteria", event))
add_members(team, %w[086.952.436-48 127.307.146-85 023.072.676-38 130.613.906-69])

# Caixas
team = find_or_build_team("Equipe Caixas", find_sector("Bilheteria", event))
add_members(team, %w[135.244.856-42 131.124.936-21 068.314.286-06 703.618.626-79 701.905.616-45 062.371.676-33 126.405.486-62 401.744.058-47 018.869.516-83 135.590.156-18 136.866.536-56 102.461.666-57 131.059.046-03 143.395.736-12 022.778.206-28 125.370.336-12 071.530.626-02 122.643.766-43 146.567.856-52 095.519.606-02 113.993.196-20 113.976.336-97 126.296.956-54 145.913.156-81 152.402.956-46 086.589.156-70 109.947.386-18 701.553.866-03 019.398.466-09 115.482.396-23 704.984.386-51 127.770.856-84 142.396.986-46 121.036.026-84 144.997.416-37 158.733.036-90 153.632.726-36 130.130.626-65 174.865.786-03 140.021.276-64 113.921.316-42 080.229.986-56 100.293.986-06 062.169.125-93 120.838.186-52 703.547.606-54 018.582.786-19])

# Remove equipes sem nenhum colaborador
Team.joins(:sector).where(sectors: { event: event }).each do |t|
  t.destroy if t.users.empty?
end

puts "   Equipes: #{Team.count} | Vínculos: #{TeamMembership.count}"
