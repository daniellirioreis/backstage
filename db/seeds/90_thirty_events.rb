# Seed: ~180 eventos variados — 5 por tipo de evento (36 tipos)
# Cada evento encerrado tem 10 setores, 1 equipe/setor, 10 colaboradores/equipe = 100/evento
# Uso: docker compose exec web rails runner db/seeds/90_thirty_events.rb

puts "\n→ Seed: ~180 eventos | 10 setores/evento | 100 colaboradores/evento"

company     = Company.first || Company.create!(name: "Produtora Horizonte")
admin       = User.joins(:role).where(roles: { name: "admin" }).first
collab_role = Role.find_by!(name: "colaborador")
abort "Admin não encontrado. Rode db:seed primeiro." unless admin

# ── Pool de 100 colaboradores ─────────────────────────────────────────────────
pool_data = [
  ["Alice Mendes",       "500.001.001-01"], ["Bruno Costa",        "500.002.002-02"],
  ["Carla Figueiredo",   "500.003.003-03"], ["Diego Almeida",      "500.004.004-04"],
  ["Elena Ramos",        "500.005.005-05"], ["Fábio Lopes",        "500.006.006-06"],
  ["Gisele Nogueira",    "500.007.007-07"], ["Henrique Duarte",    "500.008.008-08"],
  ["Inês Cavalcanti",    "500.009.009-09"], ["João Pereira",       "500.010.010-10"],
  ["Kátia Ribeiro",      "500.011.011-11"], ["Leonardo Dias",      "500.012.012-12"],
  ["Mônica Santana",     "500.013.013-13"], ["Nilton Araujo",      "500.014.014-14"],
  ["Olga Teixeira",      "500.015.015-15"], ["Pedro Machado",      "500.016.016-16"],
  ["Quirino Martins",    "500.017.017-17"], ["Regina Borges",      "500.018.018-18"],
  ["Sérgio Vieira",      "500.019.019-19"], ["Tatiana Sousa",      "500.020.020-20"],
  ["Ubiratan Campos",    "500.021.021-21"], ["Vanessa Lima",       "500.022.022-22"],
  ["Wagner Freitas",     "500.023.023-23"], ["Ximena Torres",      "500.024.024-24"],
  ["Yago Barbosa",       "500.025.025-25"], ["Zara Cunha",         "500.026.026-26"],
  ["André Medeiros",     "500.027.027-27"], ["Beatriz Fontes",     "500.028.028-28"],
  ["César Oliveira",     "500.029.029-29"], ["Diana Pinto",        "500.030.030-30"],
  ["Eduardo Matos",      "500.031.031-31"], ["Fernanda Cruz",      "500.032.032-32"],
  ["Guilherme Silva",    "500.033.033-33"], ["Helena Rocha",       "500.034.034-34"],
  ["Igor Braga",         "500.035.035-35"], ["Juliana Neto",       "500.036.036-36"],
  ["Kauan Assis",        "500.037.037-37"], ["Larissa Queiroz",    "500.038.038-38"],
  ["Marcelo Farias",     "500.039.039-39"], ["Natalia Gomes",      "500.040.040-40"],
  ["Osmar Cardoso",      "500.041.041-41"], ["Patrícia Luz",       "500.042.042-42"],
  ["Rafael Sena",        "500.043.043-43"], ["Sabrina Melo",       "500.044.044-44"],
  ["Thiago Rezende",     "500.045.045-45"], ["Ursula Vaz",         "500.046.046-46"],
  ["Vinicius Abreu",     "500.047.047-47"], ["Wanda Leite",        "500.048.048-48"],
  ["Xavier Coelho",      "500.049.049-49"], ["Yasmin Castro",      "500.050.050-50"],
  ["Zeno Pacheco",       "500.051.051-51"], ["Aline Brito",        "500.052.052-52"],
  ["Bernardo Pires",     "500.053.053-53"], ["Camille Aguiar",     "500.054.054-54"],
  ["Davi Monteiro",      "500.055.055-55"], ["Elaine Correia",     "500.056.056-56"],
  ["Felipe Barros",      "500.057.057-57"], ["Giovanna Telles",    "500.058.058-58"],
  ["Heitor Magalhães",   "500.059.059-59"], ["Isadora Ramos",      "500.060.060-60"],
  # 61–100
  ["Joana Ferraz",       "500.061.061-61"], ["Lucas Andrade",      "500.062.062-62"],
  ["Miriam Souza",       "500.063.063-63"], ["Nelson Carvalho",    "500.064.064-64"],
  ["Otávio Lima",        "500.065.065-65"], ["Priscila Mendes",    "500.066.066-66"],
  ["Renato Fonseca",     "500.067.067-67"], ["Simone Araújo",      "500.068.068-68"],
  ["Tomás Freitas",      "500.069.069-69"], ["Úrsula Dantas",      "500.070.070-70"],
  ["Valentim Rocha",     "500.071.071-71"], ["Weverton Costa",     "500.072.072-72"],
  ["Xênia Paixão",       "500.073.073-73"], ["Yasmin Nogueira",    "500.074.074-74"],
  ["Zuleica Barros",     "500.075.075-75"], ["Arthur Mota",        "500.076.076-76"],
  ["Bianca Leal",        "500.077.077-77"], ["Carlos Nunes",       "500.078.078-78"],
  ["Débora Machado",     "500.079.079-79"], ["Emerson Dias",       "500.080.080-80"],
  ["Flávia Ramos",       "500.081.081-81"], ["Gabriel Leite",      "500.082.082-82"],
  ["Humberto Viana",     "500.083.083-83"], ["Isabela Moreira",    "500.084.084-84"],
  ["Joel Batista",       "500.085.085-85"], ["Keila Pinto",        "500.086.086-86"],
  ["Luana Teixeira",     "500.087.087-87"], ["Marcos Vieira",      "500.088.088-88"],
  ["Nathalia Correia",   "500.089.089-89"], ["Otília Guimarães",   "500.090.090-90"],
  ["Pablo Nascimento",   "500.091.091-91"], ["Quésia Rezende",     "500.092.092-92"],
  ["Ricardo Alves",      "500.093.093-93"], ["Sandra Boas",        "500.094.094-94"],
  ["Tadeu Cavalcanti",   "500.095.095-95"], ["Umberto Coutinho",   "500.096.096-96"],
  ["Vera Lopes",         "500.097.097-97"], ["Willian Monteiro",   "500.098.098-98"],
  ["Xênia Duarte",       "500.099.099-99"], ["Yuri Siqueira",      "500.100.100-00"],
]

pool = pool_data.map do |name, cpf|
  u = User.find_or_initialize_by(cpf: cpf.gsub(/\D/, ""))
  if u.new_record?
    u.name     = name
    u.email    = "#{name.parameterize}@seed90.com"
    u.role     = collab_role
    u.password = "senha123"
    u.save!(validate: false)
    u.companies << company unless u.companies.include?(company)
  end
  u
end
puts "   Pool: #{pool.size} colaboradores"

# ── 10 Setores fixos (1 por evento encerrado) ─────────────────────────────────
# Cada setor tem 2 funções e recebe 10 colaboradores (= 100/evento)
sector_configs = [
  { name: "Palco",           sec_type: "stage",
    fns: [["Técnico de Som", 39.0],  ["Roadie",               20.0]] },
  { name: "Iluminação",      sec_type: "lighting",
    fns: [["Iluminador",     35.0],  ["Assistente de AV",     22.0]] },
  { name: "Som",             sec_type: "sound",
    fns: [["Sonoplasta",     39.0],  ["Técnico de Áudio",     30.0]] },
  { name: "Segurança",       sec_type: "security",
    fns: [["Segurança",      14.0],  ["Coord. de Segurança",  28.0]] },
  { name: "Entrada",         sec_type: "entrance",
    fns: [["Controle de Acesso", 14.0], ["Fiscal de Portão",  16.0]] },
  { name: "Catering",        sec_type: "catering",
    fns: [["Garçom",         15.0],  ["Cozinheiro Assist.",   25.0]] },
  { name: "Recepção",        sec_type: "reception",
    fns: [["Recepcionista",  18.0],  ["Host",                 35.0]] },
  { name: "Logística",       sec_type: "logistics",
    fns: [["Montador",       22.0],  ["Motorista",            20.0]] },
  { name: "Produção",        sec_type: "executive",
    fns: [["Assist. Produção", 30.0], ["Coordenador",         40.0]] },
  { name: "Limpeza",         sec_type: "cleaning",
    fns: [["Zelador",        12.0],  ["Serv. de Limpeza",     12.0]] },
]

# ── Cidades ───────────────────────────────────────────────────────────────────
locs = [
  "São Paulo, SP",      "Rio de Janeiro, RJ", "Belo Horizonte, MG",
  "Curitiba, PR",       "Porto Alegre, RS",   "Salvador, BA",
  "Fortaleza, CE",      "Recife, PE",         "Manaus, AM",
  "Brasília, DF",       "Goiânia, GO",        "Florianópolis, SC",
  "Natal, RN",          "Campo Grande, MS",   "Maceió, AL",
  "Teresina, PI",       "João Pessoa, PB",    "Aracaju, SE",
  "Belém, PA",          "Vitória, ES",
]

# ── Templates: 1 por tipo de evento ──────────────────────────────────────────
templates = [
  { type: "show",           prefix: "S90",  count: 5, closed: 4, dur: 1,
    names: ["Show Musical", "Show Rock", "Show MPB", "Show Sertanejo", "Show Pop"] },
  { type: "festival",       prefix: "F90",  count: 5, closed: 4, dur: 3,
    names: ["Festival de Música", "Festival de Verão", "Festival das Artes", "Festival Rock", "Festival Folk"] },
  { type: "concert",        prefix: "CO90", count: 5, closed: 4, dur: 1,
    names: ["Concerto Clássico", "Concerto Filarmônico", "Concerto ao Ar Livre", "Concerto de Câmara", "Concerto Especial"] },
  { type: "theater",        prefix: "TH90", count: 5, closed: 4, dur: 1,
    names: ["Peça Teatral", "Teatro Contemporâneo", "Gala de Teatro", "Espetáculo Dramático", "Teatro Musical"] },
  { type: "dance",          prefix: "DA90", count: 5, closed: 4, dur: 1,
    names: ["Espetáculo de Dança", "Gala de Ballet", "Festival de Dança", "Show de Dança Contemporânea", "Recital de Dança"] },
  { type: "circus",         prefix: "CI90", count: 5, closed: 4, dur: 2,
    names: ["Circo Contemporâneo", "Circo de Arte", "Grande Circo", "Circo Especial", "Espetáculo Circense"] },
  { type: "opera",          prefix: "OP90", count: 5, closed: 4, dur: 2,
    names: ["Ópera Clássica", "Grande Ópera", "Temporada de Ópera", "Gala de Ópera", "Ópera Italiana"] },
  { type: "stand_up",       prefix: "SU90", count: 5, closed: 4, dur: 1,
    names: ["Stand-up Comedy", "Noite de Comédia", "Festival de Humor", "Stand-up Show", "Gala do Riso"] },
  { type: "sports",         prefix: "SP90", count: 5, closed: 4, dur: 1,
    names: ["Evento Esportivo", "Torneio Amador", "Jogos Municipais", "Copa Esportiva", "Disputa Esportiva"] },
  { type: "race",           prefix: "RA90", count: 5, closed: 4, dur: 1,
    names: ["Corrida de Rua", "Maratona Urbana", "Corrida Noturna", "Trail Run", "Corrida Beneficente"] },
  { type: "tournament",     prefix: "TO90", count: 5, closed: 4, dur: 3,
    names: ["Torneio Regional", "Torneio Estadual", "Copa Regional", "Torneio Aberto", "Torneio Amador"] },
  { type: "championship",   prefix: "CH90", count: 5, closed: 4, dur: 3,
    names: ["Campeonato Estadual", "Campeonato Municipal", "Campeonato Regional", "Campeonato Sub-20", "Campeonato Aberto"] },
  { type: "corporate",      prefix: "CR90", count: 5, closed: 4, dur: 1,
    names: ["Evento Corporativo", "Reunião Executiva", "Encontro Empresarial", "Evento de Negócios", "Assembleia Corporativa"] },
  { type: "conference",     prefix: "CN90", count: 5, closed: 4, dur: 2,
    names: ["Congresso Nacional", "Conferência Internacional", "Encontro Técnico", "Congresso Regional", "Fórum Nacional"] },
  { type: "seminar",        prefix: "SE90", count: 5, closed: 4, dur: 1,
    names: ["Seminário de Marketing", "Seminário de Gestão", "Seminário de RH", "Seminário de Tecnologia", "Seminário Corporativo"] },
  { type: "workshop",       prefix: "WK90", count: 5, closed: 4, dur: 1,
    names: ["Workshop de Design", "Workshop de Liderança", "Workshop de Inovação", "Workshop de Marketing", "Workshop de Agile"] },
  { type: "hackathon",      prefix: "HK90", count: 5, closed: 4, dur: 2,
    names: ["Hackathon de Fintech", "Hackathon de Saúde", "Hackathon de Educação", "Hackathon de Mobilidade", "Hackathon Open"] },
  { type: "trade_show",     prefix: "TS90", count: 5, closed: 4, dur: 2,
    names: ["Feira do Empreendedor", "Feira de Tecnologia", "Feira Industrial", "Feira de Negócios", "Expo Setorial"] },
  { type: "product_launch", prefix: "PL90", count: 5, closed: 4, dur: 1,
    names: ["Lançamento de Produto", "Apresentação de Linha", "Reveal de Produto", "Lançamento Corporativo", "Lançamento de Coleção"] },
  { type: "award_ceremony", prefix: "AW90", count: 5, closed: 4, dur: 1,
    names: ["Cerimônia de Premiação", "Gala de Prêmios", "Prêmio Setorial", "Cerimônia de Honra", "Gala Anual"] },
  { type: "wedding",        prefix: "WD90", count: 5, closed: 4, dur: 1,
    names: ["Casamento Clássico", "Casamento ao Ar Livre", "Cerimônia de Casamento", "Casamento de Gala", "Casamento Intimista"] },
  { type: "graduation",     prefix: "GR90", count: 5, closed: 4, dur: 1,
    names: ["Formatura de Medicina", "Formatura de Direito", "Colação de Grau", "Formatura de Engenharia", "Formatura de Administração"] },
  { type: "birthday",       prefix: "BD90", count: 5, closed: 4, dur: 1,
    names: ["Aniversário Corporativo", "Festa de Aniversário", "Comemoração de Aniversário", "Aniversário de Empresa", "Festa Temática"] },
  { type: "debutante",      prefix: "DB90", count: 5, closed: 4, dur: 1,
    names: ["Debutante Clássica", "Festa de Debutante", "15 Anos Elegante", "Debutante Especial", "Baile de Debutante"] },
  { type: "social_gathering", prefix: "SG90", count: 5, closed: 4, dur: 1,
    names: ["Confraternização Empresarial", "Encontro Social", "Happy Hour Corporativo", "Reunião de Confraternização", "Encontro Informal"] },
  { type: "new_year",       prefix: "NY90", count: 5, closed: 4, dur: 1,
    names: ["Réveillon Premium", "Festa de Ano Novo", "Réveillon Especial", "Virada do Ano", "Réveillon Cultural"] },
  { type: "carnival",       prefix: "CA90", count: 5, closed: 4, dur: 3,
    names: ["Carnaval de Rua", "Bloco Carnavalesco", "Festa de Carnaval", "Baile de Carnaval", "Carnaval Cultural"] },
  { type: "religious",      prefix: "RL90", count: 5, closed: 4, dur: 1,
    names: ["Evento Religioso", "Encontro de Fé", "Retiro Espiritual", "Celebração Religiosa", "Vigília de Oração"] },
  { type: "church_service", prefix: "CS90", count: 5, closed: 4, dur: 1,
    names: ["Culto Especial", "Culto de Natal", "Culto de Páscoa", "Missa Solene", "Culto de Celebração"] },
  { type: "cultural",       prefix: "CU90", count: 5, closed: 4, dur: 2,
    names: ["Evento Cultural", "Mostra Cultural", "Festival de Cultura", "Semana Cultural", "Encontro Cultural"] },
  { type: "art_exhibition", prefix: "AE90", count: 5, closed: 4, dur: 3,
    names: ["Exposição de Arte Moderna", "Mostra de Arte Contemporânea", "Exposição Fotográfica", "Galeria Especial", "Bienal de Arte"] },
  { type: "gastronomy",     prefix: "GT90", count: 5, closed: 4, dur: 2,
    names: ["Festival Gastronômico", "Mostra de Gastronomia", "Semana Gourmet", "Encontro Gastronômico", "Feira de Sabores"] },
  { type: "educational",    prefix: "ED90", count: 5, closed: 4, dur: 1,
    names: ["Evento Educacional", "Encontro Pedagógico", "Fórum de Educação", "Mostra Educacional", "Congresso de Educação"] },
  { type: "lecture",        prefix: "LC90", count: 5, closed: 4, dur: 1,
    names: ["Palestra de Empreendedorismo", "Palestra de Tecnologia", "Palestra de Liderança", "Palestra de Inovação", "Palestra Motivacional"] },
  { type: "governmental",   prefix: "GV90", count: 5, closed: 4, dur: 1,
    names: ["Evento Governamental", "Sessão Pública", "Encontro Oficial", "Fórum Governamental", "Audiência Pública"] },
  { type: "other",          prefix: "OT90", count: 5, closed: 4, dur: 1,
    names: ["Evento Especial", "Evento Temático", "Evento Diverso", "Evento Variado", "Evento Livre"] },
]

# ── Limpar eventos existentes ─────────────────────────────────────────────────
print "   Apagando eventos existentes... "
Event.destroy_all
puts "✓"

# ── Geração dos eventos ───────────────────────────────────────────────────────
pool_idx    = 0          # rotação global do pool entre setores
closed_date = Date.parse("2024-01-15")
draft_date  = Date.parse("2026-07-20")
total       = 0

templates.each do |tpl|
  tpl[:count].times do |i|
    is_closed  = i < tpl[:closed]
    city       = locs[i % locs.size]
    city_short = city.split(",").first
    name       = "#{tpl[:names][i % tpl[:names].size]} — #{city_short}"
    code       = "#{tpl[:prefix]}#{(i + 1).to_s.rjust(2, '0')}"

    if is_closed
      start_date  = closed_date
      end_date    = start_date + tpl[:dur] - 1
      closed_date = end_date + 5
    else
      start_date  = draft_date
      end_date    = start_date + tpl[:dur] - 1
      draft_date  = end_date + 10
    end

    print "   [#{code}] #{name[0..44].ljust(46)} "

    # ── Evento ────────────────────────────────────────────────────────────────
    event = Event.find_or_initialize_by(code: code)
    event.assign_attributes(
      name:       name,
      company:    company,
      location:   city,
      start_date: start_date,
      end_date:   end_date,
      status:     is_closed ? "closed" : "draft",
      event_type: tpl[:type]
    )
    event.save!(validate: false)

    # ── Dias do evento ─────────────────────────────────────────────────────────
    (end_date - start_date).to_i.next.times do |d|
      ed = EventDay.find_or_initialize_by(event: event, date: start_date + d.days)
      ed.hours = 10 if ed.new_record?
      ed.save!(validate: false)
    end

    unless is_closed
      puts "[draft]"
      next
    end

    # ── 10 Setores + equipes + escalas ────────────────────────────────────────
    sectors_ok = 0
    teams_ok   = 0
    shifts_ok  = 0

    sector_configs.each do |sc|
      # -- Funções do setor
      fns = sc[:fns].map do |fn_name, rate|
        ef = EventFunction.find_or_initialize_by(event: event, name: fn_name)
        ef.hourly_rate = rate
        ef.save!(validate: false)
        ef
      end

      # -- Setor
      sector = Sector.find_or_initialize_by(name: sc[:name], event: event)
      sector.sector_type = sc[:sec_type]
      sector.save!(validate: false)

      fns.each do |ef|
        sf = SectorFunction.find_or_initialize_by(sector: sector, event_function: ef)
        sf.quantity = 5 if sf.new_record?   # 5 vagas por função → 10 por setor
        sf.save!(validate: false)
      end

      sectors_ok += 1

      # -- 10 membros para este setor (rotação global do pool)
      members = pool.rotate(pool_idx).first(10)
      pool_idx = (pool_idx + 10) % pool.size

      # -- Equipe (salva sem coordinator para evitar callback sync_coordinator_membership
      #    que chama tm.save! com validações e poderia crashar o seed)
      team = Team.find_or_initialize_by(name: "Equipe #{sc[:name]}", sector: sector)
      team.save!(validate: false)
      team.update_columns(coordinator_id: members.first.id)

      members.each_with_index do |user, idx|
        ef = fns[idx % fns.size]
        m  = TeamMembership.find_or_initialize_by(team: team, user: user)
        m.role           = idx == 0 ? :coordinator : :member
        m.event_function = ef
        m.save!(validate: false)
        user.companies << company unless user.companies.include?(company)
      end

      teams_ok += 1

      # -- Escala (1 turno por membro)
      members.each do |user|
        shift = Shift.find_or_initialize_by(
          user:   user,
          sector: sector,
          team:   team,
          date:   start_date
        )
        if shift.new_record?
          shift.start_time = Time.parse("#{start_date} 08:00")
          shift.end_time   = Time.parse("#{start_date} 17:00")
          shift.end_date   = end_date if tpl[:dur] > 1
          shift.save!(validate: false)
          shifts_ok += 1
        end
      end

      # -- Pagamentos (3 dos 10 membros)
      total_hours = tpl[:dur] * 9
      members.first(3).each do |user|
        ef = TeamMembership.find_by(team: team, user: user)&.event_function
        next unless ef&.hourly_rate.to_f > 0
        pay = Payment.find_or_initialize_by(event: event, user: user)
        if pay.new_record?
          pay.paid_by        = admin
          pay.paid_at        = end_date.to_time + 3.days
          pay.amount         = ef.hourly_rate * total_hours
          pay.hours          = total_hours
          pay.hourly_rate    = ef.hourly_rate
          pay.function_name  = ef.name
          pay.payment_method = "pix"
          pay.basis          = "cross"
          pay.save!(validate: false)
        end
      end
    end

    puts "setores: #{sectors_ok} | equipes: #{teams_ok} | escalas: #{shifts_ok}"
    total += 1
  end
end

puts ""
puts "✓ Seed concluída!"
puts ""
puts "   Eventos    : #{Event.count} (#{Event.where(status: 'closed').count} encerrados, #{Event.where(status: 'draft').count} rascunhos)"
puts "   Setores    : #{Sector.count}"
puts "   Equipes    : #{Team.count}"
puts "   Escalas    : #{Shift.count}"
puts "   Memberships: #{TeamMembership.count}"
puts "   Pagamentos : #{Payment.count}"
puts "   Tipos dist.: #{Event.where.not(event_type: [nil, '']).distinct.pluck(:event_type).size}"
puts ""
puts "  Acesse: http://localhost:3000/dashboard"
