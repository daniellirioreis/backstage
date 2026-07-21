class EventImportsController < ApplicationController
  skip_before_action :require_current_event!, only: [:new, :template, :create]

  def new
    authorize :event_import, :new?
  end

  def template
    authorize :event_import, :new?

    wb = Axlsx::Package.new
    wb.workbook do |book|
      # ── Aba 1: Evento ──────────────────────────────────────────────────────
      book.add_worksheet(name: "Evento") do |sheet|
        header_style = book.styles.add_style(
          b: true, bg_color: "18181B", fg_color: "FFFFFF",
          border: { style: :thin, color: "DDDDDD" },
          alignment: { horizontal: :center }
        )
        cell_style = book.styles.add_style(
          border: { style: :thin, color: "E4E4E7" },
          alignment: { horizontal: :left }
        )

        sheet.add_row(
          ["nome", "local", "tipo_evento", "data_inicio", "data_fim", "codigo", "horas_por_dia"],
          style: header_style
        )
        sheet.add_row(
          ["Meu Evento", "São Paulo, SP", "show", "2026-08-01", "2026-08-03", "EVT01", 8],
          style: cell_style
        )
        sheet.column_widths 30, 25, 18, 14, 14, 12, 14
      end

      # ── Aba 2: Colaboradores ───────────────────────────────────────────────
      book.add_worksheet(name: "Colaboradores") do |sheet|
        header_style = book.styles.add_style(
          b: true, bg_color: "18181B", fg_color: "FFFFFF",
          border: { style: :thin, color: "DDDDDD" },
          alignment: { horizontal: :center }
        )
        cell_style = book.styles.add_style(
          border: { style: :thin, color: "E4E4E7" },
          alignment: { horizontal: :left }
        )

        sheet.add_row(
          ["nome", "cpf", "telefone", "setor", "tipo_setor", "equipe", "funcao", "valor_hora"],
          style: header_style
        )
        sheet.add_row(
          ["João Silva", "12345678901", "11999990000",
           "Palco Principal", "stage", "Equipe A", "Operador de Som", 50.00],
          style: cell_style
        )
        sheet.add_row(
          ["Maria Santos", "98765432100", "11988880000",
           "Palco Principal", "stage", "Equipe A", "Iluminador", 45.00],
          style: cell_style
        )
        sheet.column_widths 28, 16, 16, 22, 16, 20, 22, 12
      end

      # ── Aba 3: Tipos de Evento (referência) ───────────────────────────────
      book.add_worksheet(name: "Referência - Tipos") do |sheet|
        header_style = book.styles.add_style(b: true, bg_color: "7C3AED", fg_color: "FFFFFF")
        sheet.add_row(["tipo_evento (usar na aba Evento)"], style: header_style)
        Event::EVENT_TYPES.each { |t| sheet.add_row([t]) }
        sheet.add_row([])
        sheet.add_row(["tipo_setor (usar na aba Colaboradores)"], style: header_style)
        Sector::TYPES.each { |t| sheet.add_row([t]) }
        sheet.column_widths 35
      end
    end

    send_data wb.to_stream.read,
              type:        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
              disposition: "attachment",
              filename:    "modelo_importacao_evento.xlsx"
  end

  def create
    authorize :event_import, :create?

    unless params[:file].present?
      return redirect_to new_event_import_path, alert: "Selecione um arquivo Excel (.xlsx)."
    end

    file = params[:file]
    unless File.extname(file.original_filename).downcase == ".xlsx"
      return redirect_to new_event_import_path, alert: "Formato inválido. Envie um arquivo .xlsx."
    end

    begin
      result = import_event_from_excel(file.path)
      event  = result[:event]
      session[:current_event_id] = event.id
      redirect_to event_path(event),
                  notice: "Evento \"#{event.name}\" importado com sucesso! " \
                          "#{result[:collaborators_created]} colaborador(es) adicionado(s)."
    rescue => e
      redirect_to new_event_import_path, alert: "Erro ao importar: #{e.message}"
    end
  end

  private

  def import_event_from_excel(path)
    require "roo"
    xlsx = Roo::Spreadsheet.open(path, extension: :xlsx)

    # ── Lê aba Evento ─────────────────────────────────────────────────────
    event_sheet = xlsx.sheet("Evento")
    headers     = event_sheet.row(1).map { |h| h.to_s.strip.downcase }
    values      = event_sheet.row(2)
    ev          = headers.zip(values).to_h

    name       = ev["nome"].to_s.strip
    location   = ev["local"].to_s.strip
    event_type = ev["tipo_evento"].to_s.strip
    start_date = parse_date(ev["data_inicio"])
    end_date   = parse_date(ev["data_fim"])
    code       = ev["codigo"].to_s.strip.presence
    daily_hours = ev["horas_por_dia"].to_f.then { |h| h > 0 ? h : 8.0 }

    raise "Campo 'nome' é obrigatório na aba Evento." if name.blank?
    raise "Campo 'local' é obrigatório na aba Evento." if location.blank?
    raise "Campo 'tipo_evento' inválido: #{event_type}" unless Event::EVENT_TYPES.include?(event_type)
    raise "Campo 'data_inicio' inválido." if start_date.nil?
    raise "Campo 'data_fim' inválido." if end_date.nil?
    raise "data_fim deve ser >= data_inicio." if end_date < start_date

    company = current_user.companies.first

    event = nil
    collaborators_created = 0

    ActiveRecord::Base.transaction do
      event = Event.create!(
        name:       name,
        location:   location,
        event_type: event_type,
        start_date: start_date,
        end_date:   end_date,
        code:       code,
        status:     "draft",
        company:    company
      )

      # Cria EventDays para cada dia do evento
      (start_date..end_date).each do |date|
        event.event_days.create!(date: date, hours: daily_hours)
      end

      # ── Lê aba Colaboradores ─────────────────────────────────────────────
      collab_sheet = xlsx.sheet("Colaboradores")
      col_headers  = collab_sheet.row(1).map { |h| h.to_s.strip.downcase }

      (2..collab_sheet.last_row).each do |row_num|
        row_vals = collab_sheet.row(row_num)
        next if row_vals.all?(&:blank?)

        row = col_headers.zip(row_vals).to_h

        nome       = row["nome"].to_s.strip
        cpf        = row["cpf"].to_s.strip.gsub(/\D/, "")
        telefone   = row["telefone"].to_s.strip.gsub(/\D/, "")
        setor_nome = row["setor"].to_s.strip
        tipo_setor = row["tipo_setor"].to_s.strip
        equipe_nome = row["equipe"].to_s.strip
        funcao_nome = row["funcao"].to_s.strip
        valor_hora  = row["valor_hora"].to_f

        next if nome.blank? || cpf.blank?

        # Valida tipo_setor; usa "other" se inválido
        tipo_setor = "other" unless Sector::TYPES.include?(tipo_setor)

        # Colaborador
        collaborator_role = Role.find_by(collaborator: true) || Role.first
        user = User.find_by(cpf: cpf)
        unless user
          user = User.new(
            name:                       nome,
            cpf:                        cpf,
            phone:                      telefone.presence || "00000000000",
            email:                      "#{cpf}@importado.local",
            password:                   SecureRandom.hex(12),
            role:                       collaborator_role,
            skip_required_validations:  true
          )
          user.save!
          collaborators_created += 1
        end

        # Setor
        sector = event.sectors.find_or_create_by!(name: setor_nome.presence || "Geral") do |s|
          s.sector_type = tipo_setor
        end

        # Equipe
        team = sector.teams.find_or_create_by!(name: equipe_nome.presence || "Equipe Principal")

        # Função do evento
        ef_name = funcao_nome.presence || "Colaborador"
        event_function = event.event_functions.find_or_create_by!(name: ef_name) do |ef|
          ef.hourly_rate = valor_hora
        end

        # TeamMembership
        next if TeamMembership.exists?(team: team, user: user)
        TeamMembership.create!(team: team, user: user, event_function: event_function)
      end
    end

    { event: event, collaborators_created: collaborators_created }
  end

  def parse_date(value)
    return nil if value.blank?
    return value.to_date if value.respond_to?(:to_date) && !value.is_a?(String)
    Date.parse(value.to_s)
  rescue ArgumentError
    nil
  end
end
