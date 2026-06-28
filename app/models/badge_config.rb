class BadgeConfig < ApplicationRecord
  belongs_to :event

  validates :photo_size,           numericality: { in: 40..200 }
  validates :name_font_size,       numericality: { in: 10..40 }
  validates :role_chip_font_size,  numericality: { in: 6..24 }
  validates :team_info_font_size,  numericality: { in: 6..24 }
  validates :event_name_font_size, numericality: { in: 6..24 }
  validates :event_date_font_size, numericality: { in: 4..16 }

  def self.defaults
    new(
      photo_size: 115, name_font_size: 20, role_chip_font_size: 13,
      team_info_font_size: 12, event_name_font_size: 14, event_date_font_size: 6
    )
  end
end
