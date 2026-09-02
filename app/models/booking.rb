class Booking < ApplicationRecord
  BOOKING_TYPES = %w[daily monthly meeting_hourly meeting_daily].freeze

  belongs_to :user
  belongs_to :seat
  belongs_to :order, optional: true
  belongs_to :credit_pack, optional: true

  validates :booking_type, presence: true, inclusion: { in: BOOKING_TYPES }
  validates :date, presence: true, if: -> { daily? || meeting_daily? }
  validates :starts_on, :ends_on, presence: true, if: -> { monthly? }
  validates :starts_at, :ends_at, presence: true, if: -> { meeting_hourly? }
  validate :date_not_in_past, if: -> { daily? && date.present? }
  validate :meeting_daily_advance, if: -> { meeting_daily? && date.present? }
  validate :seat_available, on: :create, if: -> { desk_booking? }
  validate :meeting_room_available, on: :create, if: -> { meeting_booking? }
  validate :meeting_room_available_on_update, on: :update, if: -> { meeting_booking? && (date_changed? || starts_at_changed?) }
  validate :seat_available_on_update, on: :update, if: -> { daily? && (date_changed? || seat_id_changed?) }
  validate :monthly_seat_available_on_update, on: :update, if: -> { monthly? && seat_id_changed? }

  scope :daily, -> { where(booking_type: "daily") }
  scope :monthly, -> { where(booking_type: "monthly") }
  scope :meeting_hourly, -> { where(booking_type: "meeting_hourly") }
  scope :meeting_daily, -> { where(booking_type: "meeting_daily") }
  scope :upcoming, -> {
    where(
      "(booking_type = 'daily' AND date >= ?) OR " \
      "(booking_type = 'monthly' AND ends_on >= ?) OR " \
      "(booking_type = 'meeting_daily' AND date >= ?) OR " \
      "(booking_type = 'meeting_hourly' AND ends_at >= ?)",
      Date.current, Date.current, Date.current, Time.current
    )
  }

  def daily?
    booking_type == "daily"
  end

  def monthly?
    booking_type == "monthly"
  end

  def meeting_hourly?
    booking_type == "meeting_hourly"
  end

  def meeting_daily?
    booking_type == "meeting_daily"
  end

  def meeting_booking?
    meeting_hourly? || meeting_daily?
  end

  def desk_booking?
    daily? || monthly?
  end

  def period_label
    if daily?
      date.strftime("%-d %B %Y")
    elsif meeting_daily?
      "#{date.strftime('%-d %B %Y')} (full day)"
    elsif meeting_hourly?
      "#{starts_at.strftime('%-d %B %Y, %H:%M')} – #{ends_at.strftime('%H:%M')}"
    else
      "#{starts_on.strftime('%-d %b')} – #{ends_on.strftime('%-d %b %Y')}"
    end
  end

  def editable?
    if meeting_hourly?
      ends_at >= Time.current
    elsif daily? || meeting_daily?
      date >= Date.current
    elsif monthly?
      ends_on >= Date.current
    else
      false
    end
  end

  private

  def date_not_in_past
    errors.add(:date, "cannot be in the past") if date < Date.current
  end

  def meeting_daily_advance
    unless MeetingRoomAvailability.daily_available?(date)
      errors.add(:date, "must be booked at least 24 hours in advance")
    end
  end

  def seat_available
    if daily?
      unless SeatAvailability.available_on?(seat, date)
        errors.add(:seat, "is not available on #{date}")
      end
    elsif monthly?
      unless SeatAvailability.available_for_monthly?(seat, starts_on, ends_on)
        errors.add(:seat, "is not available for this period")
      end
    end
  end

  def meeting_room_available
    if meeting_daily?
      unless MeetingRoomAvailability.daily_available?(date)
        errors.add(:date, "is not available")
      end
    elsif meeting_hourly?
      unless MeetingRoomAvailability.hourly_available?(starts_at, ends_at)
        errors.add(:starts_at, "is not available")
      end
    end
  end

  def meeting_room_available_on_update
    if meeting_daily?
      unless MeetingRoomAvailability.daily_available?(date, except_booking: self)
        errors.add(:date, "is not available")
      end
    elsif meeting_hourly?
      unless MeetingRoomAvailability.hourly_available?(starts_at, ends_at, except_booking: self)
        errors.add(:starts_at, "is not available")
      end
    end
  end

  def seat_available_on_update
    unless SeatAvailability.available_on?(seat, date, except_booking: self)
      errors.add(:base, "#{seat.label} is not available on #{date.strftime('%-d %B %Y')}")
    end
  end

  def monthly_seat_available_on_update
    unless SeatAvailability.available_for_monthly?(
      seat, starts_on, ends_on,
      except_booking: self,
      from_date: Date.current
    )
      errors.add(:base, "#{seat.label} is not available for this period")
    end
  end
end
