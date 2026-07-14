class Sector < ApplicationRecord
  belongs_to :event
  has_many :teams, dependent: :destroy
  has_many :shifts, dependent: :destroy
  has_many :sector_functions, dependent: :destroy
  has_many :event_functions, through: :sector_functions

  accepts_nested_attributes_for :sector_functions,
    allow_destroy: true,
    reject_if: proc { |attrs| attrs["event_function_id"].blank? }

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

  validates :name,        presence: true
  validates :sector_type, presence: true

  def planned_headcount
    sector_functions.sum(:quantity)
  end

  def sector_type_label
    return nil unless sector_type.present?
    I18n.t("sector_types.#{sector_type}", default: sector_type.humanize)
  end
end
