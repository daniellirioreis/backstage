class BadgeConfig < ApplicationRecord
  belongs_to :event

  LAYOUTS = %w[
    classic diagonal_losango arco_octogono pvc_bold dark_premium
  ].freeze

  validates :layout, inclusion: { in: LAYOUTS }, allow_blank: true
  validates :photo_size,           numericality: { in: 40..200 }
  validates :name_font_size,       numericality: { in: 10..40 }
  validates :role_chip_font_size,  numericality: { in: 6..24 }
  validates :team_info_font_size,  numericality: { in: 6..24 }
  validates :event_name_font_size, numericality: { in: 6..24 }
  validates :event_date_font_size, numericality: { in: 4..16 }

  def self.defaults
    new(
      photo_size: 115, name_font_size: 20, role_chip_font_size: 13,
      team_info_font_size: 12, event_name_font_size: 14, event_date_font_size: 6,
      event_name_color: "#4ade80", header_footer_color: "#0d0d0d", body_color: "#f5f5f4",
      name_color: "#18181b", team_info_color: "#52525b",
      credential_code_font_size: 8, credential_code_color: "#a1a1aa"
    )
  end

  def event_name_color
    self[:event_name_color].presence || "#4ade80"
  end

  def header_footer_color
    self[:header_footer_color].presence || "#0d0d0d"
  end

  def body_color
    self[:body_color].presence || "#f5f5f4"
  end

  def name_color
    self[:name_color].presence || "#18181b"
  end

  def team_info_color
    self[:team_info_color].presence || "#52525b"
  end

  def credential_code_font_size
    self[:credential_code_font_size] || 8
  end

  def credential_code_color
    self[:credential_code_color].presence || "#a1a1aa"
  end
end
