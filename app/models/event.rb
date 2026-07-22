class Event < ApplicationRecord
  belongs_to :company, optional: true
  belongs_to :closing_finalized_by, class_name: "User", optional: true

  has_many :sectors, dependent: :destroy
  has_many :teams, through: :sectors
  has_one :badge_config, dependent: :destroy
  has_many :event_functions, dependent: :destroy
  accepts_nested_attributes_for :event_functions,
                                reject_if: :all_blank,
                                allow_destroy: true

  has_many :attendances, dependent: :destroy
  has_many :payments, dependent: :destroy
  has_many :event_days, dependent: :destroy
  accepts_nested_attributes_for :event_days,
                                reject_if: :all_blank,
                                allow_destroy: true

  def total_hours
    event_days.sum(:hours).to_f
  end

  EVENT_TYPES = %w[
    show festival concert theater dance circus opera stand_up
    sports race tournament championship
    corporate conference seminar workshop hackathon trade_show product_launch award_ceremony
    wedding graduation birthday debutante social_gathering new_year carnival
    religious church_service
    cultural art_exhibition gastronomy
    educational lecture
    governmental
    other
  ].freeze

  enum :status, { draft: "draft", active: "active", closed: "closed" }, validate: true

  attr_accessor :require_step1_complete

  validates :name,       presence: true
  validates :location,   presence: true, length: { minimum: 5, message: "deve ser um endereço válido" }
  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
  validates :code, format: { with: /\A[A-Z0-9]{2,10}\z/i, message: "deve ter 2 a 10 letras/números" }, allow_blank: true
  validates :start_date, presence: true
  validates :end_date,   presence: true
  validate  :end_date_after_start_date
  validate  :at_least_one_event_day,      if: :require_step1_complete
  validate  :at_least_one_event_function, if: :require_step1_complete
  after_validation :translate_nested_errors
  after_save :geocode_location, if: :saved_change_to_location?

  private

  def geocode_location
    result = NominatimService.geocode(location)
    if result
      update_columns(
        latitude:           result[:lat],
        longitude:          result[:lon],
        location_validated: true
      )
    else
      update_columns(location_validated: false)
    end
  rescue StandardError
    # Não bloqueia o save em caso de falha na geocodificação
  end

  def end_date_after_start_date
    return if start_date.blank? || end_date.blank?
    errors.add(:end_date, :after_start_date) if end_date < start_date
  end

  def at_least_one_event_day
    valid_days = event_days.reject(&:marked_for_destruction?)
    errors.add(:base, "Adicione pelo menos um dia ao evento") if valid_days.empty?
  end

  def at_least_one_event_function
    valid_fns = event_functions.reject(&:marked_for_destruction?)
    errors.add(:base, "Adicione pelo menos uma função ao evento") if valid_fns.empty?
  end

  def translate_nested_errors
    errors.each do |error|
      attr = error.attribute.to_s
      next unless attr.start_with?("event_functions")

      # strip index notation: "event_functions[0].hourly_rate" → "hourly_rate"
      nested_attr = attr.gsub(/\Aevent_functions\[\d+\]\./, "")
      human_attr  = EventFunction.human_attribute_name(nested_attr)
      prefix      = I18n.t("activerecord.models.event_function.one", default: "Função")

      error.instance_variable_set(:@attribute, :"event_functions")
      error.instance_variable_set(
        :@full_message,
        "#{prefix} — #{human_attr} #{error.message}"
      )
    end
  end
end
