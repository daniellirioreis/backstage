class SectorFunction < ApplicationRecord
  belongs_to :sector
  belongs_to :event_function

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :event_function_id, uniqueness: {
    scope: :sector_id,
    message: "já foi adicionada a este setor"
  }

  def hourly_cost
    quantity * event_function.hourly_rate.to_f
  end

  def estimated_total_cost(event_days, hours_per_day = 8)
    hourly_cost * event_days * hours_per_day
  end
end
