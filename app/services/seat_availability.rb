class SeatAvailability
  def self.available_on?(seat, date, except_booking: nil)
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
