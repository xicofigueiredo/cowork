class Promocode < ApplicationRecord
  has_many :orders, dependent: :nullify

  before_validation :normalize_code

  validates :code, presence: true, uniqueness: { case_sensitive: false }
  validates :amount_cents, presence: true, numericality: { greater_than: 0 }
  validates :credits, presence: true, numericality: { greater_than: 0 }
  validates :active, inclusion: { in: [ true, false ] }

  scope :active, -> { where(active: true) }

  def self.find_active_by_code(code)
    normalized = code.to_s.strip.upcase
    return if normalized.blank?

    active.find_by(code: normalized)
  end

  def amount_euros
    Order.format_euros(amount_cents)
  end

  private

  def normalize_code
    self.code = code.to_s.strip.upcase.presence
  end
end
