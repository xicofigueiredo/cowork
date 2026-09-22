class AccessCode < ApplicationRecord
  SOURCES = %w[booking manual member].freeze
  STATUSES = %w[active revoked failed].freeze
  PERMANENT_YEAR = 2099

  belongs_to :booking, optional: true
  belongs_to :user, optional: true

  validates :code, presence: true
  validates :name, presence: true
  validates :valid_from, :valid_to, presence: true
  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :booking_id, uniqueness: { conditions: -> { where(status: "active") } }, allow_nil: true
  validates :user_id, uniqueness: { conditions: -> { where(status: "active") } }, allow_nil: true
  validate :valid_to_after_valid_from

  scope :active, -> { where(status: "active") }
  scope :recent_first, -> { order(created_at: :desc) }

  def self.permanent_until
    Time.zone.local(PERMANENT_YEAR, 12, 31, 23, 59, 59)
  end

  def active?
    status == "active"
  end

  def revoked?
    status == "revoked"
  end

  def failed?
    status == "failed"
  end

  # Only true when the code was accepted by TTLock (written via gateway).
  def synced_to_lock?
    active? && ttlock_keyboard_pwd_id.present?
  end

  def permanent?
    valid_to.present? && valid_to.year >= PERMANENT_YEAR
  end

  def manual?
    source == "manual"
  end

  def validity_label
    return "Permanent" if permanent?

    "#{valid_from.in_time_zone.strftime('%-d %b %Y %H:%M')} – #{valid_to.in_time_zone.strftime('%-d %b %Y %H:%M')}"
  end

  private

  def valid_to_after_valid_from
    return if valid_from.blank? || valid_to.blank?
    return if valid_to > valid_from

    errors.add(:valid_to, "must be after valid from")
  end
end
