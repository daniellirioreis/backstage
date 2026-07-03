class Payment < ApplicationRecord
  belongs_to :event
  belongs_to :user
  belongs_to :paid_by, class_name: "User"

  METHODS = %w[pix cash bank_transfer].freeze
  BASES   = %w[shifts attendance cross].freeze

  validates :amount,         presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :payment_method, inclusion: { in: METHODS }
  validates :basis,          inclusion: { in: BASES }
  validates :paid_at,        presence: true
  validates :user_id,        uniqueness: { scope: :event_id,
                                           message: "já possui pagamento registrado para este evento" }

  def method_label
    I18n.t("payment_methods.#{payment_method}", default: payment_method)
  end

  def basis_label
    I18n.t("payment_bases.#{basis}", default: basis)
  end
end
