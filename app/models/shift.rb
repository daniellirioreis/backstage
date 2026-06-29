class Shift < ApplicationRecord
  belongs_to :user
  belongs_to :sector
  belongs_to :team, optional: true

  validates :date,       presence: true
  validates :start_time, presence: true
  validates :end_time,   presence: true

  validate :end_date_not_before_start_date
  validate :end_time_not_equal_start_time
  validate :date_within_event
  validate :no_schedule_conflict

  # Retorna todas as datas cobertas pelo turno (suporte a turnos multi-dia)
  def dates
    return [date] if end_date.blank? || end_date <= date
    (date..end_date).to_a
  end

  # Formato legível do horário (suporta overnight)
  def time_range
    "#{start_time.strftime('%H:%M')} às #{end_time.strftime('%H:%M')}"
  end

  # Turno que passa da meia-noite
  def overnight?
    end_time < start_time
  end

  private

  # end_date não pode ser anterior a date
  def end_date_not_before_start_date
    return if date.blank? || end_date.blank?
    errors.add(:end_date, "não pode ser anterior à data de início") if end_date < date
  end

  # start_time e end_time não podem ser iguais
  def end_time_not_equal_start_time
    return if start_time.blank? || end_time.blank?
    errors.add(:end_time, "não pode ser igual ao horário de início") if end_time == start_time
  end

  # date e end_date dentro do período do evento
  def date_within_event
    return if date.blank? || sector_id.blank?
    event = sector&.event
    return unless event

    if date < event.start_date || date > event.end_date
      errors.add(:date, "deve estar dentro do período do evento (#{event.start_date.strftime('%d/%m/%Y')} a #{event.end_date.strftime('%d/%m/%Y')})")
    end

    if end_date.present?
      if end_date > event.end_date
        errors.add(:end_date, "não pode ultrapassar o fim do evento (#{event.end_date.strftime('%d/%m/%Y')})")
      end
    end
  end

  # Detecta conflito de horário para o mesmo colaborador
  # Considera turnos multi-dia, turnos overnight e turnos de outros eventos
  def no_schedule_conflict
    return if user_id.blank? || date.blank? || start_time.blank? || end_time.blank?

    my_end_date = end_date.presence || date

    # Busca turnos do mesmo colaborador cujo período de datas se sobrepõe ao deste turno
    # (independente do evento — valida conflito cross-evento também)
    candidates = Shift.joins(sector: :event)
                      .where(user_id: user_id)
                      .where.not(id: id)
                      .then { |q| team_id.present? ? q.where.not(team_id: team_id) : q }
                      .where(
                        "shifts.date <= ? AND COALESCE(shifts.end_date, shifts.date) >= ?",
                        my_end_date, date
                      )

    candidates.each do |other|
      next unless times_overlap?(start_time, end_time, other.start_time, other.end_time)

      event_name = other.sector&.event&.name
      period     = other.date == (other.end_date || other.date) ?
                     other.date.strftime("%d/%m/%Y") :
                     "#{other.date.strftime('%d/%m')}–#{other.end_date.strftime('%d/%m/%Y')}"

      errors.add(:base,
        "Conflito de horário com turno existente: " \
        "#{other.start_time.strftime('%H:%M')}–#{other.end_time.strftime('%H:%M')} " \
        "(#{period}#{event_name ? " · #{event_name}" : ""})"
      )
      return
    end
  end

  # Verifica se dois intervalos de horário se sobrepõem, considerando turnos overnight
  def times_overlap?(s1, e1, s2, e2)
    s1m = s1.hour * 60 + s1.min
    e1m = e1.hour * 60 + e1.min
    s2m = s2.hour * 60 + s2.min
    e2m = e2.hour * 60 + e2.min

    ov1 = e1m < s1m  # turno 1 passa da meia-noite
    ov2 = e2m < s2m  # turno 2 passa da meia-noite

    if !ov1 && !ov2
      # Ambos normais: [s1, e1) vs [s2, e2)
      s1m < e2m && s2m < e1m
    elsif ov1 && !ov2
      # Turno 1 cobre [s1, 1440) ∪ [0, e1)
      s2m < e1m || e2m > s1m
    elsif !ov1 && ov2
      # Turno 2 cobre [s2, 1440) ∪ [0, e2)
      s1m < e2m || e1m > s2m
    else
      # Ambos overnight — ambos passam pela meia-noite, sempre conflitam
      true
    end
  end
end
