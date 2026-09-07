class Order < ApplicationRecord
  IVA_RATE = BigDecimal("0.23")

  PLAN_TYPES = {
    "daily" => { amount_cents: 1300, original_amount_cents: 1500, label: "Daily pass", credits: nil },
    "pack_5" => { amount_cents: 5500, original_amount_cents: 6500, label: "5-day pack", credits: 5 },
    "pack_10" => { amount_cents: 10_000, original_amount_cents: 13_000, label: "10-day pack", credits: 10 },
    "monthly" => { amount_cents: 14_000, original_amount_cents: 15_000, label: "Monthly", credits: nil, meeting_hours: 5 },
    "meeting_hourly" => { amount_cents: 1500, label: "Hourly booking", credits: nil },
    "meeting_daily" => { amount_cents: 6500, label: "Daily booking", credits: nil }
  }.freeze

  STATUSES = %w[pending paid failed].freeze
  CREDIT_PACK_TYPES = %w[pack_5 pack_10].freeze
  DESK_PLAN_TYPES = %w[daily monthly].freeze
  MEETING_PLAN_TYPES = %w[meeting_hourly meeting_daily].freeze

  belongs_to :user
  belongs_to :seat, optional: true
  has_one :credit_pack, dependent: :destroy
  has_one :booking, dependent: :destroy

  validates :plan_type, presence: true, inclusion: { in: PLAN_TYPES.keys }
  validates :amount_cents, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validate :vat_number_format
  validates :seat, presence: true, if: :requires_desk?
  validates :booking_date, presence: true, if: -> { plan_type == "daily" || plan_type == "meeting_daily" }
  validates :starts_at, presence: true, if: -> { plan_type == "meeting_hourly" }
  validate :seat_available, if: -> { pending? && requires_desk? && seat.present? }
  validate :meeting_booking_valid, if: -> { pending? && meeting_plan? }

  before_validation :normalize_vat_number
  before_validation :assign_meeting_room_seat, if: -> { meeting_plan? && seat.blank? }

  scope :pending, -> { where(status: "pending") }
  scope :paid, -> { where(status: "paid") }

  def self.plan_config(plan_type)
    PLAN_TYPES.fetch(plan_type)
  end

  def self.original_amount_cents_for(plan_type)
    plan_config(plan_type)[:original_amount_cents]
  end

  def original_amount_cents
    self.class.original_amount_cents_for(plan_type)
  end

  def discounted?
    original_amount_cents.present? && original_amount_cents > amount_cents
  end

  def pending?
    status == "pending"
  end

  def paid?
    status == "paid"
  end

  def requires_desk?
    DESK_PLAN_TYPES.include?(plan_type)
  end

  def meeting_plan?
    MEETING_PLAN_TYPES.include?(plan_type)
  end

  def credit_pack?
    CREDIT_PACK_TYPES.include?(plan_type)
  end

  def plan_label
    PLAN_TYPES.dig(plan_type, :label)
  end

  def amount_euros
    format("%.2f €", amount_cents / 100.0)
  end

  def iva_cents
    self.class.iva_cents_for(amount_cents)
  end

  def total_with_iva_cents
    self.class.total_with_iva_cents_for(amount_cents)
  end

  def iva_euros
    self.class.format_euros(iva_cents)
  end

  def total_with_iva_euros
    self.class.format_euros(total_with_iva_cents)
  end

  def self.iva_cents_for(amount_cents)
    (amount_cents * IVA_RATE).round
  end

  def self.total_with_iva_cents_for(amount_cents)
    amount_cents + iva_cents_for(amount_cents)
  end

  def self.format_euros(cents)
    format("%.2f €", cents / 100.0)
  end

  def meeting_ends_at
    starts_at + 1.hour if starts_at.present?
  end

  def invoice_number
    date = paid_at&.in_time_zone || created_at
    "MZ-#{date.strftime('%Y%m%d')}-#{id.to_s.rjust(5, '0')}"
  end

  def customer_name
    [ user.first_name, user.last_name ].compact_blank.join(" ").presence || user.email
  end

  def fulfillment_details
    details = []

    if credit_pack?
      pack = credit_pack
      details << [ "Credits", "#{pack&.total_credits || plan_config_credits} day credits" ]
      details << [ "Valid until", pack&.expires_at&.strftime("%-d %B %Y") ] if pack&.expires_at
    elsif booking.present?
      details << [ booking.seat.meeting_room? ? "Room" : "Desk", booking.seat.label ]
      details << [ "When", booking.period_label ]
      if plan_type == "monthly" && credit_pack.present?
        details << [ "Meeting hours", "#{credit_pack.total_credits} hours included" ]
      end
    else
      details << [ "Plan", plan_label ]
    end

    details
  end

  private

  def normalize_vat_number
    if vat_number.blank?
      self.vat_number = nil
      return
    end

    self.vat_number = vat_number.to_s.upcase.gsub(/[\s.\-]/, "")
  end

  def vat_number_format
    return if vat_number.blank?

    digits = vat_number.delete_prefix("PT")
    unless digits.match?(/\A\d{9}\z/) && valid_portuguese_nif_checksum?(digits)
      errors.add(:vat_number, "must be a valid Portuguese NIF (9 digits) or PT + NIF")
    end
  end

  def valid_portuguese_nif_checksum?(nif)
    weights = [ 9, 8, 7, 6, 5, 4, 3, 2 ]
    total = nif.chars.first(8).each_with_index.sum { |digit, index| digit.to_i * weights[index] }
    check = 11 - (total % 11)
    check = 0 if check >= 10
    check == nif[8].to_i
  end

  def plan_config_credits
    self.class.plan_config(plan_type)[:credits]
  end

  def assign_meeting_room_seat
    self.seat = Seat.meeting_room
  end

  def seat_available
    if plan_type == "daily"
      unless SeatAvailability.available_on?(seat, booking_date)
        errors.add(:seat, "is not available on #{booking_date}")
      end
    elsif plan_type == "monthly"
      period = user.next_monthly_period
      unless SeatAvailability.available_for_monthly?(seat, period[:starts_on], period[:ends_on])
        errors.add(:seat, "is not available for a monthly booking")
      end
    end
  end

  def meeting_booking_valid
    if plan_type == "meeting_daily"
      unless MeetingRoomAvailability.daily_available?(booking_date)
        errors.add(:booking_date, "must be booked at least 24 hours in advance and be available")
      end
    elsif plan_type == "meeting_hourly"
      ends_at = meeting_ends_at
      unless ends_at && MeetingRoomAvailability.hourly_available?(starts_at, ends_at)
        errors.add(:starts_at, "must be booked at least 24 hours in advance and be available")
      end
    end
  end
end
