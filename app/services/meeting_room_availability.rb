class MeetingRoomAvailability
  ADVANCE_NOTICE = 24.hours
  OPEN_HOUR = 8
  CLOSE_HOUR = 20
  CALENDAR_WEEKDAYS = 14

  Schedule = Struct.new(:daily_dates, :hourly_bookings, :earliest_hourly_at, keyword_init: true) do
    def meeting_daily_on?(date)
      daily_dates.include?(date)
    end

    def hourly_overlap?(starts_at, ends_at)
      hourly_bookings.any? { |booking| booking.starts_at < ends_at && booking.ends_at > starts_at }
    end

    def hourly_available?(starts_at, ends_at)
      return false if starts_at < earliest_hourly_at
      return false unless MeetingRoomAvailability.weekday?(starts_at.to_date)
      return false unless MeetingRoomAvailability.slot_within_opening_hours?(starts_at, ends_at)
      return false if meeting_daily_on?(starts_at.to_date)
      return false if hourly_overlap?(starts_at, ends_at)

      true
    end

    def hourly_span_available?(starts_at, hours)
      hours.times.all? do |index|
        slot_start = starts_at + index.hours
        hourly_available?(slot_start, slot_start + 1.hour)
      end
    end

    def max_consecutive_hours_from(starts_at)
      max_hours = MeetingRoomAvailability::CLOSE_HOUR - starts_at.hour
      (1..max_hours).reverse_each.find { |hours| hourly_span_available?(starts_at, hours) } || 0
    end

    def hour_grid(date, include_max_duration: true)
      MeetingRoomAvailability::OPEN_HOUR.upto(MeetingRoomAvailability::CLOSE_HOUR - 1).map do |hour|
        starts_at = date.in_time_zone.change(hour: hour, min: 0)
        ends_at = starts_at + 1.hour
        available = hourly_available?(starts_at, ends_at)

        {
          starts_at: starts_at,
          ends_at: ends_at,
          label: starts_at.strftime("%H:%M"),
          available: available,
          max_duration: available && include_max_duration ? max_consecutive_hours_from(starts_at) : 0
        }
      end
    end
  end

  class << self
    def weekday?(date)
      !date.saturday? && !date.sunday?
    end

    def next_weekday(date)
      date += 1.day until weekday?(date)
      date
    end

    def ensure_weekday(date)
      weekday?(date) ? date : next_weekday(date)
    end

    def weekday_dates(from:, count: CALENDAR_WEEKDAYS)
      dates = []
      date = from

      while dates.size < count
        dates << date if weekday?(date)
        date += 1.day
      end

      dates
    end

    def earliest_hourly_at
      Time.current + ADVANCE_NOTICE
    end

    def earliest_hourly_date
      ensure_weekday(earliest_hourly_at.to_date)
    end

    def earliest_daily_date
      ensure_weekday(Date.current + 1.day)
    end

    def schedule_for(range, except_booking: nil)
      from_date = range.begin
      to_date = range.end
      scope = Booking.where(
        "(booking_type = 'meeting_daily' AND date BETWEEN ? AND ?) OR " \
        "(booking_type = 'meeting_hourly' AND starts_at BETWEEN ? AND ?)",
        from_date, to_date,
        from_date.beginning_of_day, to_date.end_of_day
      )
      scope = scope.where.not(id: except_booking.id) if except_booking

      bookings = scope.to_a
      Schedule.new(
        daily_dates: bookings.select(&:meeting_daily?).map(&:date).to_set,
        hourly_bookings: bookings.select(&:meeting_hourly?),
        earliest_hourly_at: earliest_hourly_at
      )
    end

    def daily_available?(date, except_booking: nil, schedule: nil)
      schedule ||= schedule_for(date..date, except_booking: except_booking)
      return false unless weekday?(date)
      return false if date < earliest_daily_date
      return false if schedule.meeting_daily_on?(date)
      return false if schedule.hourly_bookings.any? { |booking| booking.starts_at.to_date == date }

      true
    end

    def hourly_available?(starts_at, ends_at, except_booking: nil, schedule: nil)
      schedule ||= schedule_for(starts_at.to_date..starts_at.to_date, except_booking: except_booking)
      schedule.hourly_available?(starts_at, ends_at)
    end

    def available_hourly_slots(date, schedule: nil)
      hour_grid(date, schedule: schedule).select { |slot| slot[:available] }
    end

    def hour_grid(date, schedule: nil, include_max_duration: true)
      schedule ||= schedule_for(date..date)
      schedule.hour_grid(date, include_max_duration: include_max_duration)
    end

    def max_consecutive_hours_from(starts_at, except_booking: nil, schedule: nil)
      schedule ||= schedule_for(starts_at.to_date..starts_at.to_date, except_booking: except_booking)
      schedule.max_consecutive_hours_from(starts_at)
    end

    def hourly_span_available?(starts_at, hours, except_booking: nil, schedule: nil)
      schedule ||= schedule_for(starts_at.to_date..(starts_at.to_date + (hours - 1).days), except_booking: except_booking)
      schedule.hourly_span_available?(starts_at, hours)
    end

    def daily_calendar_days(from_date, days: CALENDAR_WEEKDAYS, schedule: nil)
      dates = weekday_dates(from: from_date, count: days)
      schedule ||= schedule_for(dates.first..dates.last)

      dates.map do |date|
        available = daily_available?(date, schedule: schedule)
        {
          date: date,
          available: available,
          meta: available ? "Available" : "Full"
        }
      end
    end

    def calendar_days(from_date, days: CALENDAR_WEEKDAYS, schedule: nil)
      dates = weekday_dates(from: from_date, count: days)
      schedule ||= schedule_for(dates.first..dates.last)

      dates.map do |date|
        slots = schedule.hour_grid(date, include_max_duration: false).count { |slot| slot[:available] }
        {
          date: date,
          available: slots.positive?,
          slot_count: slots,
          meta: slots.positive? ? "#{slots} slots" : "Full"
        }
      end
    end

    def load_calendar(from_date, type: :hourly, except_booking: nil)
      dates = weekday_dates(from: from_date)
      schedule = schedule_for(dates.first..dates.last, except_booking: except_booking)
      days = type == :daily ? daily_calendar_days(from_date, schedule: schedule) : calendar_days(from_date, schedule: schedule)
      { days: days, schedule: schedule }
    end

    def slot_within_opening_hours?(starts_at, ends_at)
      duration_hours = ((ends_at - starts_at) / 1.hour).to_i
      return false unless duration_hours.positive?

      starts_at.hour >= OPEN_HOUR &&
        (starts_at.hour + duration_hours) <= CLOSE_HOUR
    end
  end
end
