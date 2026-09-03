class SeatAvailability
  CALENDAR_WEEKDAYS = 14

  def self.available_on?(seat, date, except_booking: nil)
    return false unless weekday?(date)
    return false if date < Date.current

    !daily_booking_exists?(seat, date, except_booking: except_booking) &&
      !monthly_booking_covers?(seat, date)
  end

  def self.available_for_monthly?(seat, starts_on, ends_on, except_booking: nil, from_date: nil)
    effective_start = from_date ? [ from_date, starts_on ].max : starts_on
    return false if effective_start > ends_on
    return false if from_date.nil? && starts_on < Date.current

    !daily_bookings_in_range?(seat, effective_start, ends_on, except_booking: except_booking) &&
      !monthly_overlap?(seat, starts_on, ends_on, except_booking: except_booking)
  end

  def self.unavailable_desk_codes(date, except_booking: nil)
    return [] if date.blank?

    Seat.desks.ordered.filter_map do |seat|
      seat.code unless available_on?(seat, date, except_booking: except_booking)
    end
  end

  def self.unavailable_desk_codes_for_monthly(starts_on, ends_on, except_booking: nil, from_date: nil)
    Seat.desks.ordered.filter_map do |seat|
      seat.code unless available_for_monthly?(seat, starts_on, ends_on, except_booking: except_booking, from_date: from_date)
    end
  end

  def self.any_desk_available?(date, except_booking: nil)
    return false unless weekday?(date)
    return false if date < Date.current

    Seat.desks.any? { |seat| available_on?(seat, date, except_booking: except_booking) }
  end

  def self.calendar_days(from_date, days: CALENDAR_WEEKDAYS, except_booking: nil)
    weekday_dates(from: from_date, count: days).map do |date|
      available = any_desk_available?(date, except_booking: except_booking)
      {
        date: date,
        available: available,
        meta: available ? "Available" : "Full"
      }
    end
  end

  def self.earliest_bookable_date
    ensure_weekday(Date.current)
  end

  def self.weekday?(date)
    MeetingRoomAvailability.weekday?(date)
  end

  def self.ensure_weekday(date)
    MeetingRoomAvailability.ensure_weekday(date)
  end

  def self.weekday_dates(from:, count: CALENDAR_WEEKDAYS)
    MeetingRoomAvailability.weekday_dates(from: from, count: count)
  end

  def self.daily_booking_exists?(seat, date, except_booking: nil)
    scope = Booking.daily.where(seat: seat, date: date)
    scope = scope.where.not(id: except_booking.id) if except_booking
    scope.exists?
  end

  def self.monthly_booking_covers?(seat, date)
    Booking.monthly.where(seat: seat)
      .where("starts_on <= ? AND ends_on >= ?", date, date)
      .exists?
  end

  def self.daily_bookings_in_range?(seat, starts_on, ends_on, except_booking: nil)
    scope = Booking.daily.where(seat: seat).where(date: starts_on..ends_on)
    scope = scope.where.not(id: except_booking.id) if except_booking&.daily?
    scope.exists?
  end

  def self.monthly_overlap?(seat, starts_on, ends_on, except_booking: nil)
    scope = Booking.monthly.where(seat: seat)
      .where("starts_on <= ? AND ends_on >= ?", ends_on, starts_on)
    scope = scope.where.not(id: except_booking.id) if except_booking
    scope.exists?
  end
end
