class Payment < ApplicationRecord
  belongs_to :event
  belongs_to :user
  belongs_to :paid_by, class_name: "User"

  METHODS        = %w[pix cash bank_transfer].freeze
  BASES          = %w[shifts attendance cross manual].freeze
  WAIVED_REASONS = %w[absence resignation other].freeze

  validates :amount,         presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :payment_method, inclusion: { in: METHODS }, unless: :waived?
  validates :basis,          inclusion: { in: BASES }
  validates :paid_at,        presence: true
  validates :waived_reason,  inclusion: { in: WAIVED_REASONS }, presence: true, if: :waived?
  validates :date,           presence: true
  validates :user_id,        uniqueness: { scope: [:event_id, :date],
                                           message: "já possui pagamento registrado para este evento nesta data" }

  def method_label
    return waived_reason_label if waived?
    I18n.t("payment_methods.#{payment_method}", default: payment_method)
  end

  def basis_label
    I18n.t("payment_bases.#{basis}", default: basis)
  end

  def waived_reason_label
    return "—" if waived_reason.blank?
    I18n.t("waived_reasons.#{waived_reason}", default: waived_reason.to_s.humanize)
  end
end
