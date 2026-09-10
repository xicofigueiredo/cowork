class AccessCode < ApplicationRecord
  SOURCES = %w[booking manual].freeze
  STATUSES = %w[active revoked failed].freeze

  belongs_to :booking, optional: true
  belongs_to :user, optional: true

  validates :code, presence: true
  validates :name, presence: true
  validates :valid_from, :valid_to, presence: true
  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :booking_id, uniqueness: { conditions: -> { where(status: "active") } }, allow_nil: true
  validate :valid_to_after_valid_from

  scope :active, -> { where(status: "active") }
  scope :recent_first, -> { order(created_at: :desc) }

  def active?
    status == "active"
  end

  def revoked?
    status == "revoked"
  end

  def failed?
    status == "failed"
  end

  def manual?
    source == "manual"
  end

  def validity_label
    "#{valid_from.in_time_zone.strftime('%-d %b %Y %H:%M')} – #{valid_to.in_time_zone.strftime('%-d %b %Y %H:%M')}"
  end

  private

  def valid_to_after_valid_from
    return if valid_from.blank? || valid_to.blank?
    return if valid_to > valid_from

    errors.add(:valid_to, "must be after valid from")
  end
end
