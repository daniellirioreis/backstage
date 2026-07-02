class Sector < ApplicationRecord
  belongs_to :event
  has_many :teams, dependent: :destroy
  has_many :shifts, dependent: :destroy

  TYPES = %w[
    stage lighting sound generator tents
    security entrance parking
    reception ticketing catering bar
    executive logistics press
    health cleaning backstage
    decoration photo_video entertainment
    other
  ].freeze

  enum :sector_type, TYPES.index_by { |t| t.to_sym }

  validates :name, presence: true
  validates :expected_headcount, numericality: { only_integer: true, greater_than: 0, allow_nil: true }

  def sector_type_label
    return nil unless sector_type.present?
    I18n.t("sector_types.#{sector_type}", default: sector_type.humanize)
  end
end
