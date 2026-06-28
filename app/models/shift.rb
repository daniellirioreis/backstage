class Shift < ApplicationRecord
  belongs_to :user
  belongs_to :sector
  belongs_to :team, optional: true

  validates :date, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true
  validate :end_time_after_start_time
  validate :no_schedule_conflict
  validate :date_within_event
  validate :team_without_existing_shifts, on: :create

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

  def end_time_after_start_time
    return if start_time.blank? || end_time.blank?
    # Turnos overnight (ex: 16:00 → 04:00) são válidos
    return if overnight?
    errors.add(:end_time, :after_start_time) if end_time <= start_time
  end

  def team_without_existing_shifts
    return if team_id.blank?
    if Shift.where(team_id: team_id).exists?
      errors.add(:base, "Esta equipe já possui escala definida")
    end
  end

  def date_within_event
    return if date.blank? || sector_id.blank?
    event = sector&.event
    return unless event
    if date < event.start_date || date > event.end_date
      errors.add(:date, "deve estar dentro do período do evento (#{event.start_date.strftime('%d/%m/%Y')} a #{event.end_date.strftime('%d/%m/%Y')})")
    end
    if end_date.present? && end_date > event.end_date
      errors.add(:end_date, "não pode ultrapassar o fim do evento (#{event.end_date.strftime('%d/%m/%Y')})")
    end
  end

  def no_schedule_conflict
    return if user_id.blank? || date.blank? || start_time.blank? || end_time.blank?

    conflict = Shift.where(user_id: user_id, date: date)
                    .where.not(id: id)
                    .where("start_time < ? AND end_time > ?", end_time, start_time)

    errors.add(:base, :schedule_conflict) if conflict.exists?
  end
end
