class SeatAvailability
  CALENDAR_WEEKDAYS = 14
  SAME_DAY_CUTOFF_HOUR = 17
  PENDING_HOLD_TTL = 15.minutes

  def self.available_on?(seat, date, except_booking: nil, except_order: nil, ignore_pending: false)
    return false unless weekday?(date)
    return false if date < minimum_bookable_date

    available = !daily_booking_exists?(seat, date, except_booking: except_booking) &&
      !monthly_booking_covers?(seat, date, except_booking: except_booking)
    return available if ignore_pending

    available &&
      !pending_daily_hold?(seat, date, except_order: except_order) &&
      !pending_monthly_covers_date?(seat, date, except_order: except_order)
  end

  def self.available_for_monthly?(seat, starts_on, ends_on, except_booking: nil, except_order: nil, from_date: nil, ignore_pending: false)
    effective_start = from_date ? [ from_date, starts_on ].max : starts_on
    return false if effective_start > ends_on
    return false if from_date.nil? && starts_on < Date.current

    available = !daily_bookings_in_range?(seat, effective_start, ends_on, except_booking: except_booking) &&
      !monthly_overlap?(seat, starts_on, ends_on, except_booking: except_booking)
    return available if ignore_pending

    available &&
      !pending_daily_in_range?(seat, effective_start, ends_on, except_order: except_order) &&
      !pending_monthly_overlap?(seat, starts_on, ends_on, except_order: except_order)
  end

  def self.unavailable_desk_codes(date, except_booking: nil, except_order: nil)
    return [] if date.blank?

    Seat.desks.ordered.filter_map do |seat|
      seat.code unless available_on?(seat, date, except_booking: except_booking, except_order: except_order)
    end
  end

  # desk code => { name:, booking_type: } for bookings covering the given date
  def self.desk_occupancy_for(date)
    return {} if date.blank?

    bookings = Booking.desk_covering(date).includes(:user, :seat)
    bookings.each_with_object({}) do |booking, occupancy|
      user = booking.user
      name = [ user.first_name, user.last_name ].compact_blank.join(" ").presence || user.email
      occupancy[booking.seat.code] = {
        name: name,
        booking_type: booking.booking_type
      }
    end
  end

  def self.unavailable_desk_codes_for_monthly(starts_on, ends_on, except_booking: nil, except_order: nil, from_date: nil)
    Seat.desks.ordered.filter_map do |seat|
      seat.code unless available_for_monthly?(
        seat, starts_on, ends_on,
        except_booking: except_booking,
        except_order: except_order,
        from_date: from_date
      )
    end
  end

  def self.any_desk_available?(date, except_booking: nil, except_order: nil)
    return false unless weekday?(date)
    return false if date < minimum_bookable_date

    Seat.desks.any? { |seat| available_on?(seat, date, except_booking: except_booking, except_order: except_order) }
  end

  def self.calendar_days(from_date, days: CALENDAR_WEEKDAYS, except_booking: nil, except_order: nil)
    weekday_dates(from: from_date, count: days).map do |date|
      available = any_desk_available?(date, except_booking: except_booking, except_order: except_order)
      {
        date: date,
        available: available,
        meta: available ? "Available" : "Full"
      }
    end
  end

  # Today is bookable until 17:00 Lisbon time; after that, the next calendar day.
  def self.minimum_bookable_date
    if Time.zone.now.hour >= SAME_DAY_CUTOFF_HOUR
      Date.current + 1.day
    else
      Date.current
    end
  end

  def self.earliest_bookable_date
    ensure_weekday(minimum_bookable_date)
  end

  def self.bookable_date?(date)
    weekday?(date) && date >= minimum_bookable_date
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

  def self.monthly_booking_covers?(seat, date, except_booking: nil)
    scope = Booking.monthly.where(seat: seat)
      .where("starts_on <= ? AND ends_on >= ?", date, date)
    scope = scope.where.not(id: except_booking.id) if except_booking
    scope.exists?
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

  def self.pending_hold_scope(except_order: nil)
    scope = Order.pending.where("orders.created_at > ?", PENDING_HOLD_TTL.ago)
    scope = scope.where.not(id: except_order.id) if except_order&.persisted?
    scope
  end

  def self.pending_daily_hold?(seat, date, except_order: nil)
    pending_hold_scope(except_order: except_order)
      .where(plan_type: "daily", seat_id: seat.id, booking_date: date)
      .exists?
  end

  def self.pending_daily_in_range?(seat, starts_on, ends_on, except_order: nil)
    pending_hold_scope(except_order: except_order)
      .where(plan_type: "daily", seat_id: seat.id, booking_date: starts_on..ends_on)
      .exists?
  end

  def self.pending_monthly_covers_date?(seat, date, except_order: nil)
    pending_monthly_orders(seat, except_order: except_order).any? do |order|
      period = order.user.next_monthly_period(months: order.desk_months)
      period[:starts_on] <= date && period[:ends_on] >= date
    end
  end

  def self.pending_monthly_overlap?(seat, starts_on, ends_on, except_order: nil)
    pending_monthly_orders(seat, except_order: except_order).any? do |order|
      period = order.user.next_monthly_period(months: order.desk_months)
      period[:starts_on] <= ends_on && period[:ends_on] >= starts_on
    end
  end

  def self.pending_monthly_orders(seat, except_order: nil)
    pending_hold_scope(except_order: except_order)
      .where(plan_type: Order::MONTHLY_DESK_PLAN_TYPES, seat_id: seat.id)
      .includes(:user)
  end
  private_class_method :pending_monthly_orders
end
