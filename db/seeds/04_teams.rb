puts "→ Criando equipes e colaboradores..."

colab_role = Role.find_by!(name: "colaborador")
event      = Event.find_by!(name: "Boombay 2026")

def find_or_create_user(name:, cpf:, phone: nil, role:)
  return nil if name.blank? || cpf.blank?
  clean_cpf = cpf.to_s.gsub(/\D/, "").strip
  return nil if clean_cpf.length != 11

  User.find_or_create_by!(cpf: clean_cpf) do |u|
    u.name     = name.to_s.strip
    u.phone    = phone.to_s.gsub(/\D/, "").then { |p| p.length >= 8 ? p : "00000000000" }
    u.email    = "#{clean_cpf}@boombay.com"
    u.password = "senha123"
    u.role     = role
  end
rescue ActiveRecord::RecordInvalid => e
  puts "  AVISO: #{name} (#{clean_cpf}) — #{e.message}"
  nil
end

# ── CARREGADORES ──────────────────────────────────────────────────────────────
team_carr = Team.find_or_create_by!(name: "Carregadores", event: event)

[
  { name: "Vinicius Lopes Alves",      cpf: "111.138.456-86", phone: "(31) 97229-5007" },
  { name: "Fernando Lucas Cota",       cpf: "113.701.166-16", phone: "(31) 98936-5301" },
  { name: "Heitor Lincoln",            cpf: "189.397.846-00" },
  { name: "Fabricio Teixeira",         cpf: "045.558.156-88", phone: "(31) 99330-8331" },
  { name: "Antonio Luiz Alves",        cpf: "096.798.656-57", phone: "(31) 99562-6639" },
  { name: "Bruno Cota",                cpf: "127.266.296-95" },
  { name: "Arthur Pereira Lima Cunha", cpf: "103.537.666-07" },
  { name: "Lindsley Thompson Leroy",   cpf: "018.641.666-06" },
].each do |m|
  u = find_or_create_user(**m, role: colab_role)
  TeamMembership.find_or_create_by!(team: team_carr, user: u) if u
end

# ── LIMPEZA ───────────────────────────────────────────────────────────────────
team_limp = Team.find_or_create_by!(name: "Limpeza", event: event)

[
  { name: "Eduarda Moura",            cpf: "133.176.676-13" },
  { name: "Ingrid Lorraine Pereira",  cpf: "706.568.186-62" },
  { name: "Maria Eduarda Neves",      cpf: "020.676.386-70" },
  { name: "Gilberto Pereira",         cpf: "898.395.446-91" },
  { name: "Queli Felipe Neves",       cpf: "074.342.076-47" },
  { name: "Nayara Cristina de Jesus", cpf: "105.705.936-62" },
  { name: "Cristina de Jesus Ricoli", cpf: "026.190.866-98" },
  { name: "João Vitor Moreira",       cpf: "173.532.966-58" },
  { name: "Igor Vinicius dos Santos", cpf: "155.546.046-17" },
  { name: "Gabriel Angelo",           cpf: "167.066.496-19" },
  { name: "Cleusa Diniz Pinto",       cpf: "897.944.516-49" },
  { name: "Elizabeth Rodrigues",      cpf: "855.196.426-72" },
  { name: "Ana Clara Gonçalves",      cpf: "705.701.196-26" },
  { name: "Alisson Alair dos Santos", cpf: "001.270.096-71" },
  { name: "Vitoria Silva Gomes",      cpf: "177.178.706-65" },
  { name: "Kathleen Vitoria",         cpf: "193.362.326-81" },
  { name: "Mari Luiza Pereira",       cpf: "079.852.876-12" },
  { name: "Fabiola de Cassia",        cpf: "055.950.006-86" },
  { name: "Weverson Cristiano",       cpf: "053.262.116-61" },
  { name: "Italo Gabriel",            cpf: "703.938.846-43" },
  { name: "Reniel Domingos Souza",    cpf: "005.268.915-80" },
].each do |m|
  u = find_or_create_user(**m, role: colab_role)
  TeamMembership.find_or_create_by!(team: team_limp, user: u) if u
end

# ── LOJINHA & GUARDA VOLUMES ──────────────────────────────────────────────────
team_loja = Team.find_or_create_by!(name: "Lojinha & Guarda Volumes", event: event)

%w[Guarda\ Volumes Guarda\ Volume\ Staff Lojinha Controle\ de\ Consumo Mega\ Fone Backstage Estoque\ Lojinha].each do |s|
  Sector.find_or_create_by!(name: s, team: team_loja)
end

[
  { name: "Melissa da Silva Fonseca", cpf: "162.735.106-01" },
  { name: "Ellen Almeida",            cpf: "121.186.756-22" },
  { name: "Stephany Kennedy",         cpf: "130.760.326-23" },
  { name: "Vinicius Costa",           cpf: "101.587.516-55" },
  { name: "Deusler Bueno",            cpf: "141.128.446-11" },
  { name: "Larissa Rocha Amaral",     cpf: "154.195.356-88" },
  { name: "Maria Laura",              cpf: "087.004.756-61" },
  { name: "Laura Faria",              cpf: "113.976.276-11" },
  { name: "Karen Ketelly Cunha",      cpf: "704.232.906-65" },
  { name: "Grazi Lopes",              cpf: "123.242.986-43" },
  { name: "Kenia Caroline Fontes",    cpf: "023.157.276-00" },
  { name: "Tamires Raine Araujo",     cpf: "133.441.326-60" },
  { name: "Rafael Theodoro",          cpf: "141.085.536-83" },
  { name: "Camilly Stefany Fonseca",  cpf: "125.432.956-07" },
  { name: "Pedro Henrique Santos",    cpf: "143.799.776-76" },
  { name: "Stefani Mares Ferreira",   cpf: "117.485.696-35" },
].each do |m|
  u = find_or_create_user(**m, role: colab_role)
  TeamMembership.find_or_create_by!(team: team_loja, user: u) if u
end

# ── CAIXAS ────────────────────────────────────────────────────────────────────
team_caixas = Team.find_or_create_by!(name: "Caixas", event: event)

[
  { name: "Kimberly Madgem",             cpf: "135.244.856-42" },
  { name: "Rayssa Mendes",               cpf: "131.124.936-21" },
  { name: "Cleide Barbosa",              cpf: "068.314.286-06" },
  { name: "Gabriel Santos",              cpf: "703.618.626-79" },
  { name: "Larissa Vitoria",             cpf: "701.905.616-45" },
  { name: "Flavio Huertas",              cpf: "062.371.676-33" },
  { name: "Pollyanny Luizzy",            cpf: "126.405.486-62" },
  { name: "William Jordão",              cpf: "401.744.058-47" },
  { name: "Icaro Matias",                cpf: "018.869.516-83" },
  { name: "Delio David",                 cpf: "135.590.156-18" },
  { name: "Tainara Morais e Silva",      cpf: "136.866.536-56" },
  { name: "Larissa Francielle",          cpf: "102.461.666-57" },
  { name: "Pedro Grabiel Valverde",      cpf: "131.059.046-03" },
  { name: "Raphael Santos",              cpf: "143.395.736-12" },
  { name: "Maranúbia Ferreira",          cpf: "022.778.206-28" },
  { name: "Joseph Lucas",                cpf: "125.370.336-12" },
  { name: "Fernando Cesar",              cpf: "071.530.626-02" },
  { name: "Andressa Martins",            cpf: "122.643.766-43" },
  { name: "Tifany Francisca",            cpf: "146.567.856-52" },
  { name: "Laende Nayara",               cpf: "095.519.606-02" },
  { name: "Lanna Silva",                 cpf: "113.993.196-20" },
  { name: "Lais Faria",                  cpf: "113.976.336-97" },
  { name: "Ludmila Cristo",              cpf: "126.296.956-54" },
  { name: "Ana Beatriz Nunes",           cpf: "145.913.156-81" },
  { name: "Matheus Faustino",            cpf: "152.402.956-46" },
  { name: "Danubia Rafaela de Oliveira", cpf: "086.589.156-70" },
  { name: "Giselle Vieira",              cpf: "109.947.386-18" },
  { name: "Victoria Izabella",           cpf: "701.553.866-03" },
  { name: "Ana Carolina Cardoso",        cpf: "019.398.466-09" },
  { name: "Amanda Cristina Batista",     cpf: "115.482.396-23" },
  { name: "Francielly Bitencourt",       cpf: "704.984.386-51" },
  { name: "Amanda Bueno",                cpf: "127.770.856-84" },
  { name: "Raquel Barreto",              cpf: "142.396.986-46" },
  { name: "Johan de Sena Alves",         cpf: "121.036.026-84" },
  { name: "Beatriz Coelho",              cpf: "144.997.416-37" },
  { name: "Kaique Eduardo",              cpf: "158.733.036-90" },
  { name: "Enzo Fernandes",              cpf: "153.632.726-36" },
  { name: "Pedro Henrique Bortolo",      cpf: "130.130.626-65" },
  { name: "Joao Vitor Fernandes",        cpf: "174.865.786-03" },
  { name: "Marcos Vinicius Gomes",       cpf: "140.021.276-64" },
  { name: "Jessica Kellen",              cpf: "113.921.316-42" },
  { name: "Gianni Iago Ribeiro",         cpf: "080.229.986-56" },
  { name: "Desyree Barcellos",           cpf: "100.293.986-06" },
  { name: "Islene Monteiro",             cpf: "062.169.125-93" },
  { name: "Natalia Gomes",               cpf: "120.838.186-52" },
  { name: "Emanuelly Toledo",            cpf: "703.547.606-54" },
  { name: "Lindsey Leroy",               cpf: "018.582.786-19" },
].each do |m|
  u = find_or_create_user(**m, role: colab_role)
  TeamMembership.find_or_create_by!(team: team_caixas, user: u) if u
end

# ── BILHETERIA ────────────────────────────────────────────────────────────────
team_bilh = Team.find_or_create_by!(name: "Bilheteria", event: event)

["Caixa Ticket Social", "Troca de Alimento", "Bilheteria"].each do |s|
  Sector.find_or_create_by!(name: s, team: team_bilh)
end

[
  { name: "Robert Cristian Gomes",    cpf: "108.283.596-01" },
  { name: "Sthefany Soares",          cpf: "161.102.466-89" },
  { name: "Samuel Trancoso",          cpf: "116.589.546-37" },
  { name: "João Felipe Teixeira",     cpf: "702.407.736-08" },
  { name: "Raquel Victoria Santos",   cpf: "702.325.956-23" },
  { name: "Danielle Ribeiro",         cpf: "118.177.326-17" },
  { name: "Ana Cristina Pires",       cpf: "128.356.386-01" },
  { name: "Diogo Gustavo Rodrigues",  cpf: "018.311.916-95" },
  { name: "Gustavo Rezende",          cpf: "022.580.686-06" },
  { name: "Lucas Cesar Modesto",      cpf: "098.460.196-10" },
  { name: "Luana Beatriz da Silva",   cpf: "144.853.166-70" },
  { name: "Meiriele Nascimento",      cpf: "086.952.436-48" },
  { name: "Pamela Cristina Barcelos", cpf: "127.307.146-85" },
  { name: "Paula Cristina F. Miranda", cpf: "023.072.676-38" },
  { name: "Thayanne Ferraz",          cpf: "130.613.906-69" },
].each do |m|
  u = find_or_create_user(**m, role: colab_role)
  TeamMembership.find_or_create_by!(team: team_bilh, user: u) if u
end

puts "   Equipes: #{Team.count} | Colaboradores: #{User.count - 1}"
