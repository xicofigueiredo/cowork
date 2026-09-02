class CreditPack < ApplicationRecord
  CREDIT_TYPES = %w[day meeting_hour].freeze

  belongs_to :user
  belongs_to :order
  has_many :bookings, dependent: :nullify

  validates :total_credits, :remaining_credits, presence: true, numericality: { greater_than: 0 }
  validates :expires_at, presence: true
  validates :credit_type, presence: true, inclusion: { in: CREDIT_TYPES }
  validate :remaining_not_exceeds_total

  scope :active, -> { where("remaining_credits > 0 AND expires_at > ?", Time.current) }
  scope :day_credits, -> { where(credit_type: "day") }
  scope :meeting_hour_credits, -> { where(credit_type: "meeting_hour") }
  scope :usable, -> { active.order(:expires_at) }

  def expired?
    expires_at <= Time.current
  end

  def usable?
    return false unless remaining_credits.positive? && !expired?
    return true unless meeting_hour_credits?

    active_period?
  end

  def upcoming?
    meeting_hour_credits? && order&.booking&.starts_on&.>(Date.current)
  end

  def active_period?
    booking = order&.booking
    return false unless booking&.starts_on && booking.ends_on

    booking.starts_on <= Date.current && booking.ends_on >= Date.current
  end

  def day_credits?
    credit_type == "day"
  end

  def meeting_hour_credits?
    credit_type == "meeting_hour"
  end

  def credit_label
    meeting_hour_credits? ? "hour".pluralize(remaining_credits) : "credit".pluralize(remaining_credits)
  end

  def use_credit!(amount = 1)
    raise "No credits remaining" unless usable?
    raise "Not enough credits" if remaining_credits < amount

    decrement!(:remaining_credits, amount)
  end

  private

  def remaining_not_exceeds_total
    return unless remaining_credits && total_credits

    errors.add(:remaining_credits, "cannot exceed total credits") if remaining_credits > total_credits
  end
end
