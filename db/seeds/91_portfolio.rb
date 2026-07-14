# db/seeds/91_portfolio.rb
#
# Seed de portfólio: 14 eventos (12 fechados + 2 ativos)
# 200 colaboradores, 6+ tipos de evento, heatmap rico, pagamentos distribuídos
# em 12 meses para gráfico de evolução de custo.

puts "\n→ Seed Portfolio (14 eventos, 200 colaboradores)"

company     = Company.first || Company.create!(name: "Produtora Horizonte")
admin       = User.joins(:role).where(roles: { name: "admin" }).first
collab_role = Role.find_by!(name: "colaborador")
abort "Admin não encontrado. Rode db:seed primeiro." unless admin

# ═══════════════════════════════════════════════════════════════════════════════
# POOL DE 200 COLABORADORES
# ═══════════════════════════════════════════════════════════════════════════════

colabs_data = [
  # 001-020 — Equipe de palco e audiovisual (core)
  ["Rafael Cunha",          "791.001.001-01"], ["Beatriz Fontes",       "791.002.002-02"],
  ["Lucas Drummond",        "791.003.003-03"], ["Ana Silveira",         "791.004.004-04"],
  ["Rodrigo Mendes",        "791.005.005-05"], ["Camila Ferreira",      "791.006.006-06"],
  ["Felipe Andrade",        "791.007.007-07"], ["Juliana Castro",       "791.008.008-08"],
  ["Marcos Leal",           "791.009.009-09"], ["Patrícia Coelho",      "791.010.010-10"],
  ["Thiago Batista",        "791.011.011-11"], ["Vanessa Lima",         "791.012.012-12"],
  ["Eduardo Ramos",         "791.013.013-13"], ["Fernanda Nunes",       "791.014.014-14"],
  ["Gustavo Prado",         "791.015.015-15"], ["Helena Vasconcelos",   "791.016.016-16"],
  ["Leandro Sousa",         "791.017.017-17"], ["Monica Teixeira",      "791.018.018-18"],
  ["Paulo Henrique",        "791.019.019-19"], ["Simone Araújo",        "791.020.020-20"],

  # 021-060 — Equipe de segurança (core, aparecem em vários eventos)
  ["Carlos Menezes",        "791.021.021-21"], ["Renata Pinheiro",      "791.022.022-22"],
  ["Alexandre Braga",       "791.023.023-23"], ["Daniela Rocha",        "791.024.024-24"],
  ["Fábio Santos",          "791.025.025-25"], ["Gisele Mota",          "791.026.026-26"],
  ["Henrique Dias",         "791.027.027-27"], ["Isabela Martins",      "791.028.028-28"],
  ["Jorge Alves",           "791.029.029-29"], ["Karine Borges",        "791.030.030-30"],
  ["Leonardo Cardoso",      "791.031.031-31"], ["Larissa Queiroz",      "791.032.032-32"],
  ["Marcelo Farias",        "791.033.033-33"], ["Natalia Gomes",        "791.034.034-34"],
  ["Osmar Vieira",          "791.035.035-35"], ["Priscila Luz",         "791.036.036-36"],
  ["Rafael Sena",           "791.037.037-37"], ["Sabrina Melo",         "791.038.038-38"],
  ["Thiago Rezende",        "791.039.039-39"], ["Ursula Vaz",           "791.040.040-40"],
  ["Vinicius Abreu",        "791.041.041-41"], ["Wanda Leite",          "791.042.042-42"],
  ["Xavier Coelho",         "791.043.043-43"], ["Yasmin Castro",        "791.044.044-44"],
  ["Anderson Lima",         "791.045.045-45"], ["Bruna Carvalho",       "791.046.046-46"],
  ["Cesar Oliveira",        "791.047.047-47"], ["Denise Pinto",         "791.048.048-48"],
  ["Erick Moreira",         "791.049.049-49"], ["Fabiana Cruz",         "791.050.050-50"],
  ["Giovani Silva",         "791.051.051-51"], ["Hariana Rocha",        "791.052.052-52"],
  ["Ivan Braga",            "791.053.053-53"], ["Joana Neto",           "791.054.054-54"],
  ["Kevin Assis",           "791.055.055-55"], ["Luciana Queiroz",      "791.056.056-56"],
  ["Murilo Farias",         "791.057.057-57"], ["Nathalia Gomes",       "791.058.058-58"],
  ["Otávio Cardoso",        "791.059.059-59"], ["Paloma Luz",           "791.060.060-60"],

  # 061-100 — Recepção, bilheteria e portaria
  ["Quirino Martins",       "791.061.061-61"], ["Roberta Mendes",       "791.062.062-62"],
  ["Samuel Trancoso",       "791.063.063-63"], ["Tainara Morais",       "791.064.064-64"],
  ["Ulisses Borges",        "791.065.065-65"], ["Vera Costa",           "791.066.066-66"],
  ["Wagner Freitas",        "791.067.067-67"], ["Xuxa Leite",           "791.068.068-68"],
  ["Yago Barbosa",          "791.069.069-69"], ["Zara Cunha",           "791.070.070-70"],
  ["André Medeiros",        "791.071.071-71"], ["Bianca Fontes",        "791.072.072-72"],
  ["Caio Drummond",         "791.073.073-73"], ["Dayane Silveira",      "791.074.074-74"],
  ["Evandro Menezes",       "791.075.075-75"], ["Flavia Pinheiro",      "791.076.076-76"],
  ["Guilherme Braga",       "791.077.077-77"], ["Hellen Rocha",         "791.078.078-78"],
  ["Isadora Santos",        "791.079.079-79"], ["Jonatas Mota",         "791.080.080-80"],
  ["Kamila Dias",           "791.081.081-81"], ["Leonardo Martins",     "791.082.082-82"],
  ["Matheus Alves",         "791.083.083-83"], ["Nayara Borges",        "791.084.084-84"],
  ["Orlandina Cardoso",     "791.085.085-85"], ["Pedro Vieira",         "791.086.086-86"],
  ["Quezia Lima",           "791.087.087-87"], ["Ricardo Melo",         "791.088.088-88"],
  ["Silvana Rezende",       "791.089.089-89"], ["Tamiris Abreu",        "791.090.090-90"],
  ["Umberto Leite",         "791.091.091-91"], ["Vanusa Coelho",        "791.092.092-92"],
  ["Willian Castro",        "791.093.093-93"], ["Xisto Lima",           "791.094.094-94"],
  ["Yara Oliveira",         "791.095.095-95"], ["Zenaide Cruz",         "791.096.096-96"],
  ["Abner Silva",           "791.097.097-97"], ["Bernadete Rocha",      "791.098.098-98"],
  ["Cleber Braga",          "791.099.099-99"], ["Dafne Neto",           "791.100.100-00"],

  # 101-140 — Bar, catering, limpeza
  ["Elias Assis",           "792.101.101-01"], ["Flor Queiroz",         "792.102.102-02"],
  ["Geraldo Farias",        "792.103.103-03"], ["Hildete Gomes",        "792.104.104-04"],
  ["Inácio Cardoso",        "792.105.105-05"], ["Jaqueline Luz",        "792.106.106-06"],
  ["Kerlon Martins",        "792.107.107-07"], ["Leidiane Mendes",      "792.108.108-08"],
  ["Mercia Trancoso",       "792.109.109-09"], ["Nilo Morais",          "792.110.110-10"],
  ["Odair Borges",          "792.111.111-11"], ["Palmira Costa",        "792.112.112-12"],
  ["Quiteria Freitas",      "792.113.113-13"], ["Reinaldo Leite",       "792.114.114-14"],
  ["Sueli Barbosa",         "792.115.115-15"], ["Telma Cunha",          "792.116.116-16"],
  ["Uendel Medeiros",       "792.117.117-17"], ["Valquíria Fontes",     "792.118.118-18"],
  ["Welinton Drummond",     "792.119.119-19"], ["Xênia Silveira",       "792.120.120-20"],
  ["Yolanda Menezes",       "792.121.121-21"], ["Zoraide Pinheiro",     "792.122.122-22"],
  ["Amilton Braga",         "792.123.123-23"], ["Bartolomeu Rocha",     "792.124.124-24"],
  ["Conceição Santos",      "792.125.125-25"], ["Divaldo Mota",         "792.126.126-26"],
  ["Eurico Dias",           "792.127.127-27"], ["Fátima Martins",       "792.128.128-28"],
  ["Gertrudes Alves",       "792.129.129-29"], ["Horácio Borges",       "792.130.130-30"],
  ["Iolanda Cardoso",       "792.131.131-31"], ["Jacira Vieira",        "792.132.132-32"],
  ["Kenio Lima",            "792.133.133-33"], ["Luzinete Melo",        "792.134.134-34"],
  ["Marlene Rezende",       "792.135.135-35"], ["Niomar Abreu",         "792.136.136-36"],
  ["Olindina Leite",        "792.137.137-37"], ["Percival Coelho",      "792.138.138-38"],
  ["Quinzeiro Castro",      "792.139.139-39"], ["Raimunda Lima",        "792.140.140-40"],

  # 141-170 — Logística, montagem, motoristas
  ["Salmito Oliveira",      "792.141.141-41"], ["Tereza Cruz",          "792.142.142-42"],
  ["Uziel Silva",           "792.143.143-43"], ["Valdirene Rocha",      "792.144.144-44"],
  ["Waldemar Braga",        "792.145.145-45"], ["Ximenes Neto",         "792.146.146-46"],
  ["Yedda Assis",           "792.147.147-47"], ["Zuleide Queiroz",      "792.148.148-48"],
  ["Aldair Farias",         "792.149.149-49"], ["Bernadinha Gomes",     "792.150.150-50"],
  ["Cicero Cardoso",        "792.151.151-51"], ["Dalva Luz",            "792.152.152-52"],
  ["Elzinete Martins",      "792.153.153-53"], ["Florinda Mendes",      "792.154.154-54"],
  ["Gildasio Trancoso",     "792.155.155-55"], ["Honório Morais",       "792.156.156-56"],
  ["Iraci Borges",          "792.157.157-57"], ["Juvenal Costa",        "792.158.158-58"],
  ["Kozan Freitas",         "792.159.159-59"], ["Lindoura Leite",       "792.160.160-60"],
  ["Mocinha Barbosa",       "792.161.161-61"], ["Nomar Cunha",          "792.162.162-62"],
  ["Orlanda Medeiros",      "792.163.163-63"], ["Pero Fontes",          "792.164.164-64"],
  ["Quincas Drummond",      "792.165.165-65"], ["Rosalba Silveira",     "792.166.166-66"],
  ["Saturnino Menezes",     "792.167.167-67"], ["Telêmaco Pinheiro",    "792.168.168-68"],
  ["Uberlândia Braga",      "792.169.169-69"], ["Valdomiro Rocha",      "792.170.170-70"],

  # 171-200 — Produção executiva, coordenadores
  ["Wladimir Santos",       "792.171.171-71"], ["Xenofonte Mota",       "792.172.172-72"],
  ["Yaredy Dias",           "792.173.173-73"], ["Zélia Martins",        "792.174.174-74"],
  ["Aristides Alves",       "792.175.175-75"], ["Benedita Borges",      "792.176.176-76"],
  ["Consolação Cardoso",    "792.177.177-77"], ["Dolores Vieira",       "792.178.178-78"],
  ["Eugênio Lima",          "792.179.179-79"], ["Floripes Melo",        "792.180.180-80"],
  ["Genoveva Rezende",      "792.181.181-81"], ["Hilarino Abreu",       "792.182.182-82"],
  ["Ipojuca Leite",         "792.183.183-83"], ["Jezabel Coelho",       "792.184.184-84"],
  ["Kimberlândia Castro",   "792.185.185-85"], ["Lucivânio Lima",       "792.186.186-86"],
  ["Melquisedec Oliveira",  "792.187.187-87"], ["Normândia Cruz",       "792.188.188-88"],
  ["Oduvaldo Silva",        "792.189.189-89"], ["Perpétua Rocha",       "792.190.190-90"],
  ["Quesnel Braga",         "792.191.191-91"], ["Romildo Neto",         "792.192.192-92"],
  ["Serafina Assis",        "792.193.193-93"], ["Tiburínio Queiroz",    "792.194.194-94"],
  ["Umbelinda Farias",      "792.195.195-95"], ["Vespasiano Gomes",     "792.196.196-96"],
  ["Wanderlândia Cardoso",  "792.197.197-97"], ["Xenofânio Luz",        "792.198.198-98"],
  ["Yolanda Martins",       "792.199.199-99"], ["Zumbi Mendes",         "792.200.200-00"],
]

print "   Criando 200 colaboradores... "
pool = colabs_data.map do |name, cpf|
  cpf_clean = cpf.gsub(/\D/, "")
  email = "#{name.parameterize(separator: ".")}@produtorahorizonte.com"
  u = User.find_by(cpf: cpf_clean) || User.find_by(email: email)
  unless u
    u = User.new(cpf: cpf_clean, name: name, email: email,
                 role: collab_role, password: "senha123",
                 phone: "31999#{cpf_clean[-5..-1]}")
    u.save!(validate: false)
  end
  u.companies << company unless u.companies.include?(company)
  u
end
puts "#{pool.size} ✓"

# ═══════════════════════════════════════════════════════════════════════════════
# FUNÇÕES DO CATÁLOGO
# ═══════════════════════════════════════════════════════════════════════════════

def fn_rate(name)
  catalog = EventFunction.find_by(event_id: nil, name: name)
  return catalog.hourly_rate if catalog
  defaults = {
    "Coordenador de Produção" => 40.0,
    "Assistente de Produção"  => 30.0,
    "Técnico de Som"          => 39.0,
    "Técnico de Iluminação"   => 39.0,
    "Técnico de AV"           => 35.0,
    "Iluminador"              => 35.0,
    "Operador de Câmera"      => 30.0,
    "Host"                    => 35.0,
    "Roadie"                  => 20.0,
    "Assistente de Palco"     => 15.0,
    "Segurança"               => 20.0,
    "Coord. de Segurança"     => 28.0,
    "Recepcionista"           => 15.0,
    "Caixa de Bilheteria"     => 10.0,
    "Montador"                => 22.0,
    "Motorista"               => 20.0,
    "Bartender"               => 18.0,
    "Garçom"                  => 15.0,
    "Atendente de Bar"        => 12.0,
    "Cozinheiro"              => 25.0,
    "Agente de Limpeza"       => 12.0,
    "Socorrista"              => 35.0,
    "Aux. de Enfermagem"      => 28.0,
  }
  defaults[name] || 15.0
end

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURAÇÃO DOS 14 EVENTOS
# ═══════════════════════════════════════════════════════════════════════════════
#
# Notação de membros: índices do pool (0-based)
# Setores definem :functions => [[nome, índices_dos_membros]]
#
# ═══════════════════════════════════════════════════════════════════════════════

events_config = [

  # ── 1. Festival Rock in BH — Aug 2025 (3 dias, festival, 5 setores) ─────────
  {
    name: "Festival Rock in BH", code: "RCKBH25",
    event_type: "festival", location: "Belo Horizonte, MG",
    start_date: Date.new(2025, 8, 15), end_date: Date.new(2025, 8, 17),
    status: "closed",
    sectors: [
      { name: "Palco / Estrutura", type: "stage",
        fns: [["Roadie", (0..4)], ["Assistente de Palco", (5..8)]],
        shift: ["14:00","23:00"] },
      { name: "Som / Audiovisual", type: "sound",
        fns: [["Técnico de Som", (9..12)], ["Técnico de AV", (13..15)]],
        shift: ["13:00","23:00"] },
      { name: "Iluminação", type: "lighting",
        fns: [["Técnico de Iluminação", (16..18)], ["Iluminador", (19..20)]],
        shift: ["13:00","23:00"] },
      { name: "Segurança", type: "security",
        fns: [["Segurança", (21..44)], ["Coord. de Segurança", (45..46)]],
        shift: ["12:00","23:00"] },
      { name: "Produção Executiva", type: "executive",
        fns: [["Coordenador de Produção", (172..174)], ["Assistente de Produção", (175..179)]],
        shift: ["10:00","23:00"] },
    ],
  },

  # ── 2. Show Samba da Capital — Set 2025 (1 dia, show) ───────────────────────
  {
    name: "Show Samba da Capital", code: "SAMBA25",
    event_type: "show", location: "Belo Horizonte, MG",
    start_date: Date.new(2025, 9, 6), end_date: Date.new(2025, 9, 6),
    status: "closed",
    sectors: [
      { name: "Palco / Estrutura", type: "stage",
        fns: [["Técnico de Som", (0..2)], ["Roadie", (3..6)]],
        shift: ["15:00","23:00"] },
      { name: "Segurança", type: "security",
        fns: [["Segurança", (21..34)], ["Coord. de Segurança", (47..47)]],
        shift: ["14:00","23:00"] },
      { name: "Portaria / Credenciamento", type: "entrance",
        fns: [["Recepcionista", (60..64)], ["Caixa de Bilheteria", (65..67)]],
        shift: ["14:00","22:00"] },
    ],
  },

  # ── 3. Congresso Inovação Tech — Set 2025 (2 dias, conference) ──────────────
  {
    name: "Congresso Inovação Tech", code: "CIT25",
    event_type: "conference", location: "São Paulo, SP",
    start_date: Date.new(2025, 9, 18), end_date: Date.new(2025, 9, 19),
    status: "closed",
    sectors: [
      { name: "Recepção", type: "reception",
        fns: [["Recepcionista", (60..68)], ["Host", (9..10)]],
        shift: ["08:00","18:00"] },
      { name: "Som / Audiovisual", type: "sound",
        fns: [["Técnico de AV", (13..16)], ["Operador de Câmera", (17..18)]],
        shift: ["08:00","18:00"] },
      { name: "Segurança", type: "security",
        fns: [["Segurança", (35..44)], ["Coord. de Segurança", (48..48)]],
        shift: ["07:00","19:00"] },
      { name: "Alimentação / Catering", type: "catering",
        fns: [["Cozinheiro", (101..104)], ["Garçom", (105..110)]],
        shift: ["07:00","19:00"] },
    ],
  },

  # ── 4. Corrida das Nações — Out 2025 (1 dia, race) ──────────────────────────
  {
    name: "Corrida das Nações BH", code: "CDN25",
    event_type: "race", location: "Belo Horizonte, MG",
    start_date: Date.new(2025, 10, 11), end_date: Date.new(2025, 10, 11),
    status: "closed",
    sectors: [
      { name: "Segurança", type: "security",
        fns: [["Segurança", (21..40)], ["Coord. de Segurança", (49..50)]],
        shift: ["05:00","14:00"] },
      { name: "Saúde / Emergência", type: "health",
        fns: [["Socorrista", (180..183)], ["Aux. de Enfermagem", (184..186)]],
        shift: ["05:00","14:00"] },
      { name: "Logística / Transporte", type: "logistics",
        fns: [["Montador", (141..148)], ["Motorista", (149..154)]],
        shift: ["04:00","14:00"] },
    ],
  },

  # ── 5. Festival Cultural SP — Out 2025 (4 dias, cultural) ───────────────────
  {
    name: "Festival Cultural SP", code: "FCSP25",
    event_type: "cultural", location: "São Paulo, SP",
    start_date: Date.new(2025, 10, 23), end_date: Date.new(2025, 10, 26),
    status: "closed",
    sectors: [
      { name: "Palco / Estrutura", type: "stage",
        fns: [["Assistente de Palco", (0..6)], ["Roadie", (7..11)]],
        shift: ["12:00","22:00"] },
      { name: "Som / Audiovisual", type: "sound",
        fns: [["Técnico de Som", (9..13)], ["Técnico de AV", (14..16)]],
        shift: ["11:00","22:00"] },
      { name: "Segurança", type: "security",
        fns: [["Segurança", (22..39)], ["Coord. de Segurança", (51..52)]],
        shift: ["10:00","22:00"] },
      { name: "Recepção", type: "reception",
        fns: [["Recepcionista", (69..75)], ["Host", (10..11)]],
        shift: ["10:00","20:00"] },
      { name: "Limpeza", type: "cleaning",
        fns: [["Agente de Limpeza", (111..122)]],
        shift: ["08:00","16:00"] },
    ],
  },

  # ── 6. Carnaval BH 2026 — Nov 2025 (6 dias, carnival) — MAIOR EVENTO ────────
  {
    name: "Carnaval BH 2026", code: "CRBH26",
    event_type: "carnival", location: "Belo Horizonte, MG",
    start_date: Date.new(2025, 11, 1), end_date: Date.new(2025, 11, 6),
    status: "closed",
    sectors: [
      { name: "Palco / Estrutura", type: "stage",
        fns: [["Roadie", (0..8)], ["Assistente de Palco", (5..14)], ["Montador", (141..145)]],
        shift: ["10:00","04:00"] },
      { name: "Som / Audiovisual", type: "sound",
        fns: [["Técnico de Som", (9..13)], ["Técnico de Iluminação", (16..20)], ["Técnico de AV", (13..16)]],
        shift: ["10:00","04:00"] },
      { name: "Segurança", type: "security",
        fns: [["Segurança", (21..59)], ["Coord. de Segurança", (45..55)]],
        shift: ["16:00","06:00"] },
      { name: "Portaria / Credenciamento", type: "entrance",
        fns: [["Recepcionista", (60..79)], ["Caixa de Bilheteria", (80..89)]],
        shift: ["14:00","04:00"] },
      { name: "Bar", type: "bar",
        fns: [["Bartender", (100..112)], ["Atendente de Bar", (113..122)]],
        shift: ["16:00","04:00"] },
      { name: "Limpeza", type: "cleaning",
        fns: [["Agente de Limpeza", (123..139)]],
        shift: ["06:00","22:00"] },
    ],
  },

  # ── 7. ExpoArte Horizonte — Nov 2025 (3 dias, art_exhibition) ───────────────
  {
    name: "ExpoArte Horizonte", code: "EXPO25",
    event_type: "art_exhibition", location: "Belo Horizonte, MG",
    start_date: Date.new(2025, 11, 20), end_date: Date.new(2025, 11, 22),
    status: "closed",
    sectors: [
      { name: "Recepção", type: "reception",
        fns: [["Recepcionista", (60..66)], ["Host", (9..10)]],
        shift: ["09:00","19:00"] },
      { name: "Segurança", type: "security",
        fns: [["Segurança", (35..44)], ["Coord. de Segurança", (53..53)]],
        shift: ["08:00","20:00"] },
      { name: "Montagem / Logística", type: "logistics",
        fns: [["Montador", (155..161)], ["Motorista", (162..164)]],
        shift: ["07:00","17:00"] },
      { name: "Produção Executiva", type: "executive",
        fns: [["Assistente de Produção", (187..191)], ["Coordenador de Produção", (192..193)]],
        shift: ["08:00","20:00"] },
    ],
  },

  # ── 8. Réveillon Horizonte 2026 — Dez 2025 (2 dias, new_year) ───────────────
  {
    name: "Réveillon Horizonte 2026", code: "REV26",
    event_type: "new_year", location: "Belo Horizonte, MG",
    start_date: Date.new(2025, 12, 31), end_date: Date.new(2026, 1, 1),
    status: "closed",
    sectors: [
      { name: "Palco / Estrutura", type: "stage",
        fns: [["Técnico de Som", (0..4)], ["Roadie", (5..11)], ["Iluminador", (19..21)]],
        shift: ["14:00","06:00"] },
      { name: "Som / Audiovisual", type: "sound",
        fns: [["Técnico de AV", (13..17)], ["Operador de Câmera", (17..19)]],
        shift: ["12:00","06:00"] },
      { name: "Segurança", type: "security",
        fns: [["Segurança", (21..53)], ["Coord. de Segurança", (54..56)]],
        shift: ["18:00","08:00"] },
      { name: "Bar", type: "bar",
        fns: [["Bartender", (100..108)], ["Garçom", (109..118)]],
        shift: ["18:00","06:00"] },
      { name: "Produção Executiva", type: "executive",
        fns: [["Coordenador de Produção", (194..196)], ["Assistente de Produção", (197..199)]],
        shift: ["10:00","08:00"] },
    ],
  },

  # ── 9. Gala Corporativa Horizonte — Dez 2025 (1 dia, corporate) ─────────────
  {
    name: "Gala Corporativa Horizonte", code: "GCH25",
    event_type: "corporate", location: "Belo Horizonte, MG",
    start_date: Date.new(2025, 12, 6), end_date: Date.new(2025, 12, 6),
    status: "closed",
    sectors: [
      { name: "Recepção", type: "reception",
        fns: [["Recepcionista", (67..72)], ["Host", (10..12)]],
        shift: ["18:00","23:00"] },
      { name: "Palco / Estrutura", type: "stage",
        fns: [["Técnico de Som", (0..2)], ["Iluminador", (19..20)]],
        shift: ["15:00","23:00"] },
      { name: "Segurança", type: "security",
        fns: [["Segurança", (35..42)], ["Coord. de Segurança", (57..57)]],
        shift: ["17:00","23:00"] },
      { name: "Alimentação / Catering", type: "catering",
        fns: [["Cozinheiro", (101..104)], ["Garçom", (105..112)]],
        shift: ["16:00","23:00"] },
    ],
  },

  # ── 10. Torneio BH Cup — Fev 2026 (2 dias, tournament) ─────────────────────
  {
    name: "Torneio BH Cup 2026", code: "BHCUP26",
    event_type: "tournament", location: "Belo Horizonte, MG",
    start_date: Date.new(2026, 2, 7), end_date: Date.new(2026, 2, 8),
    status: "closed",
    sectors: [
      { name: "Segurança", type: "security",
        fns: [["Segurança", (21..38)], ["Coord. de Segurança", (45..47)]],
        shift: ["07:00","19:00"] },
      { name: "Saúde / Emergência", type: "health",
        fns: [["Socorrista", (180..183)], ["Aux. de Enfermagem", (184..187)]],
        shift: ["07:00","19:00"] },
      { name: "Logística / Transporte", type: "logistics",
        fns: [["Montador", (155..162)], ["Motorista", (163..167)]],
        shift: ["06:00","16:00"] },
      { name: "Portaria / Credenciamento", type: "entrance",
        fns: [["Recepcionista", (73..79)], ["Caixa de Bilheteria", (80..83)]],
        shift: ["08:00","18:00"] },
    ],
  },

  # ── 11. Festival Gastronômico MG — Mar 2026 (3 dias, gastronomy) ─────────────
  {
    name: "Festival Gastronômico MG", code: "GASTRO26",
    event_type: "gastronomy", location: "Belo Horizonte, MG",
    start_date: Date.new(2026, 3, 14), end_date: Date.new(2026, 3, 16),
    status: "closed",
    sectors: [
      { name: "Recepção", type: "reception",
        fns: [["Recepcionista", (60..67)], ["Host", (12..13)]],
        shift: ["11:00","22:00"] },
      { name: "Alimentação / Catering", type: "catering",
        fns: [["Cozinheiro", (101..112)], ["Garçom", (113..122)]],
        shift: ["09:00","22:00"] },
      { name: "Segurança", type: "security",
        fns: [["Segurança", (35..46)], ["Coord. de Segurança", (58..59)]],
        shift: ["10:00","22:00"] },
      { name: "Produção Executiva", type: "executive",
        fns: [["Assistente de Produção", (188..192)], ["Coordenador de Produção", (193..194)]],
        shift: ["08:00","22:00"] },
    ],
  },

  # ── 12. Hackathon Open BH — Mar 2026 (2 dias, hackathon) ────────────────────
  {
    name: "Hackathon Open BH 2026", code: "HACK26",
    event_type: "hackathon", location: "Belo Horizonte, MG",
    start_date: Date.new(2026, 3, 28), end_date: Date.new(2026, 3, 29),
    status: "closed",
    sectors: [
      { name: "Recepção", type: "reception",
        fns: [["Recepcionista", (73..77)], ["Host", (13..14)]],
        shift: ["08:00","20:00"] },
      { name: "Som / Audiovisual", type: "sound",
        fns: [["Técnico de AV", (14..16)], ["Operador de Câmera", (17..18)]],
        shift: ["08:00","20:00"] },
      { name: "Produção Executiva", type: "executive",
        fns: [["Assistente de Produção", (195..198)], ["Coordenador de Produção", (199..199)]],
        shift: ["07:00","21:00"] },
    ],
  },

  # ── 13. Show de Verão SP — Abr 2026 (1 dia, show) ───────────────────────────
  {
    name: "Show de Verão SP", code: "SVSP26",
    event_type: "show", location: "São Paulo, SP",
    start_date: Date.new(2026, 4, 12), end_date: Date.new(2026, 4, 12),
    status: "closed",
    sectors: [
      { name: "Palco / Estrutura", type: "stage",
        fns: [["Técnico de Som", (0..3)], ["Roadie", (4..8)], ["Iluminador", (19..21)]],
        shift: ["15:00","23:00"] },
      { name: "Segurança", type: "security",
        fns: [["Segurança", (21..34)], ["Coord. de Segurança", (48..49)]],
        shift: ["14:00","23:00"] },
      { name: "Bar", type: "bar",
        fns: [["Bartender", (100..105)], ["Atendente de Bar", (106..110)]],
        shift: ["16:00","23:00"] },
    ],
  },

  # ── 14. Boombay 2026 — Abr/Mai 2026 (9 dias, festival, ATIVO) ───────────────
  {
    name: "Boombay 2026", code: "BBY26",
    event_type: "festival", location: "Belo Horizonte, MG",
    start_date: Date.new(2026, 4, 18), end_date: Date.new(2026, 4, 26),
    status: "active",
    sectors: [
      { name: "Palco / Estrutura", type: "stage",
        fns: [["Roadie", (0..9)], ["Assistente de Palco", (5..14)], ["Montador", (141..148)]],
        shift: ["14:00","02:00"] },
      { name: "Som / Audiovisual", type: "sound",
        fns: [["Técnico de Som", (9..14)], ["Técnico de Iluminação", (16..20)], ["Técnico de AV", (13..16)]],
        shift: ["12:00","02:00"] },
      { name: "Iluminação", type: "lighting",
        fns: [["Iluminador", (19..23)], ["Técnico de Iluminação", (16..18)]],
        shift: ["12:00","02:00"] },
      { name: "Segurança", type: "security",
        fns: [["Segurança", (21..59)], ["Coord. de Segurança", (45..59)]],
        shift: ["12:00","04:00"] },
      { name: "Portaria / Credenciamento", type: "entrance",
        fns: [["Recepcionista", (60..89)], ["Caixa de Bilheteria", (80..99)]],
        shift: ["12:00","02:00"] },
      { name: "Bar", type: "bar",
        fns: [["Bartender", (100..112)], ["Atendente de Bar", (113..122)]],
        shift: ["16:00","04:00"] },
      { name: "Limpeza", type: "cleaning",
        fns: [["Agente de Limpeza", (123..139)]],
        shift: ["06:00","22:00"] },
      { name: "Produção Executiva", type: "executive",
        fns: [["Coordenador de Produção", (170..174)], ["Assistente de Produção", (175..184)]],
        shift: ["08:00","23:00"] },
    ],
  },

]

# ═══════════════════════════════════════════════════════════════════════════════
# GERAÇÃO DOS EVENTOS
# ═══════════════════════════════════════════════════════════════════════════════

events_config.each do |cfg|
  event_status = cfg[:status]
  num_days     = (cfg[:end_date] - cfg[:start_date]).to_i + 1

  print "\n   [#{cfg[:code]}] #{cfg[:name].ljust(35)} "

  # ── Evento ──────────────────────────────────────────────────────────────────
  event = Event.find_or_initialize_by(code: cfg[:code])
  event.assign_attributes(
    name:       cfg[:name],
    company:    company,
    location:   cfg[:location],
    start_date: cfg[:start_date],
    end_date:   cfg[:end_date],
    status:     event_status,
    event_type: cfg[:event_type],
  )
  event.save!(validate: false)

  # ── Dias do evento ───────────────────────────────────────────────────────────
  hours_per_day = {
    "festival"      => 14, "show"       => 10, "conference"   => 10,
    "race"          => 12, "cultural"   => 12, "carnival"     => 18,
    "art_exhibition"=> 10, "new_year"   => 14, "corporate"    => 8,
    "tournament"    => 12, "gastronomy" => 12, "hackathon"    => 14,
    "award_ceremony"=> 8,
  }
  event_hours = hours_per_day[cfg[:event_type]] || 10

  (cfg[:start_date]..cfg[:end_date]).each do |date|
    ed = EventDay.find_or_initialize_by(event: event, date: date)
    ed.hours = event_hours
    ed.save!(validate: false)
  end

  # ── Setores, equipes, escalas, pagamentos ────────────────────────────────────
  paid_at = cfg[:end_date].to_time + 5.days

  cfg[:sectors].each do |sc|
    # Coletar membros únicos do setor
    members = sc[:fns].flat_map { |_, range| pool[range] }.uniq.compact

    # Funções do evento
    ef_map = sc[:fns].map do |fn_name, _|
      rate = fn_rate(fn_name)
      ef = EventFunction.find_or_initialize_by(event: event, name: fn_name)
      ef.hourly_rate = rate
      ef.save!(validate: false)
      [fn_name, ef]
    end.to_h

    # Setor
    sector = Sector.find_or_initialize_by(name: sc[:name], event: event)
    sector.sector_type = sc[:type]
    sector.save!(validate: false)

    # SectorFunctions
    ef_map.each do |fn_name, ef|
      sf = SectorFunction.find_or_initialize_by(sector: sector, event_function: ef)
      sf.quantity = (members.size.to_f / ef_map.size).ceil if sf.new_record?
      sf.save!(validate: false)
    end

    # Equipe
    team_name = "Equipe #{sc[:name]}"
    team = Team.find_or_initialize_by(name: team_name, sector: sector)
    team.save!(validate: false)
    team.update_columns(coordinator_id: members.first.id) if members.any?

    # Memberships (round-robin de funções entre membros)
    fn_list = ef_map.values
    members.each_with_index do |user, idx|
      ef = fn_list[idx % fn_list.size]
      m  = TeamMembership.find_or_initialize_by(team: team, user: user)
      m.role           = idx == 0 ? :coordinator : :member
      m.event_function = ef
      m.save!(validate: false)
      user.companies << company unless user.companies.include?(company)
    end

    # Calcular horas do turno
    sh_start = sc[:shift][0]
    sh_end   = sc[:shift][1]
    s_time   = Time.parse("2000-01-01 #{sh_start}")
    e_time   = Time.parse("2000-01-0#{sh_end > sh_start ? '1' : '2'} #{sh_end}")
    shift_hours = ((e_time - s_time) / 3600.0).abs.round(1)
    total_hours = (shift_hours * num_days).round(1)

    # Escalas
    (cfg[:start_date]..cfg[:end_date]).each do |date|
      members.each do |user|
        shift = Shift.find_or_initialize_by(user: user, sector: sector, team: team, date: date)
        if shift.new_record?
          base = DateTime.new(date.year, date.month, date.day)
          shift.start_time = base + sh_start.split(":").then { |h, m| h.to_i.hours + m.to_i.minutes }
          end_hour = sh_end.split(":").then { |h, m| h.to_i.hours + m.to_i.minutes }
          end_hour += 1.day if sh_end <= sh_start  # virada de dia
          shift.end_time = base + end_hour
          shift.save!(validate: false)
        end
      end
    end

    # Attendances — eventos fechados: ~90% de presença
    if event_status == "closed"
      (cfg[:start_date]..cfg[:end_date]).each do |date|
        members.each do |user|
          next if rand(100) < 10  # 10% de ausência
          shift = Shift.find_by(user: user, sector: sector, team: team, date: date)
          next unless shift

          att = Attendance.find_or_initialize_by(user: user, event: event, checked_in_date: date)
          if att.new_record?
            att.team           = team
            att.checked_in_at  = shift.start_time + rand(1..15).minutes
            att.checked_out_at = shift.end_time   - rand(1..10).minutes
            att.checked_in_by  = admin
            att.checked_out_by = admin
            att.save!(validate: false)
          end
        end
      end

    elsif event_status == "active"
      # Ativo: 60% check-in no primeiro dia, sem checkout
      first_day = cfg[:start_date]
      members.each do |user|
        next if rand(100) < 40  # 40% ainda não chegaram
        shift = Shift.find_by(user: user, sector: sector, team: team, date: first_day)
        next unless shift

        att = Attendance.find_or_initialize_by(user: user, event: event, checked_in_date: first_day)
        if att.new_record?
          att.team          = team
          att.checked_in_at = shift.start_time + rand(1..20).minutes
          att.checked_in_by = admin
          att.save!(validate: false)
        end
      end
    end

    # Pagamentos — somente eventos fechados, 100% dos membros
    next unless event_status == "closed"

    members.each_with_index do |user, idx|
      ef = fn_list[idx % fn_list.size]
      next unless ef&.hourly_rate.to_f > 0

      pay = Payment.find_or_initialize_by(event: event, user: user)
      next unless pay.new_record?

      pay.paid_by        = admin
      pay.paid_at        = paid_at + rand(0..3).days
      pay.amount         = (ef.hourly_rate * total_hours).round(2)
      pay.hours          = total_hours
      pay.hourly_rate    = ef.hourly_rate
      pay.function_name  = ef.name
      pay.payment_method = %w[pix pix pix bank_transfer cash].sample
      pay.basis          = "cross"
      pay.save!(validate: false)
    end

    member_count = members.size
    print "#{member_count}p "
  end

  puts ""
end

# ═══════════════════════════════════════════════════════════════════════════════
# RESUMO
# ═══════════════════════════════════════════════════════════════════════════════

total_payments = Payment.sum(:amount)

puts ""
puts "✓ Seed portfolio concluída!"
puts ""
puts "   Colaboradores : #{User.count - 1}"
puts "   Eventos       : #{Event.count} (#{Event.where(status: 'closed').count} fechados · #{Event.where(status: 'active').count} ativos)"
puts "   Setores       : #{Sector.count}"
puts "   Equipes       : #{Team.count}"
puts "   Memberships   : #{TeamMembership.count}"
puts "   Escalas       : #{Shift.count}"
puts "   Attendances   : #{Attendance.count}"
puts "   Pagamentos    : #{Payment.count} · R$#{format('%.2f', total_payments)}"
puts ""
puts "   Acesse: http://localhost:3000"
