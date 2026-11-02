# frozen_string_literal: true

module GoogleCalendar
  class InboundSync
    LOOKAHEAD = 3.months
    LOOKBACK = 1.day

    def self.call(client: Client.new)
      new(client: client).call
    end

    def initialize(client:)
      @client = client
    end

    def call
      return { skipped: true } unless Client.configured?

      time_min = LOOKBACK.ago.beginning_of_day
      time_max = LOOKAHEAD.from_now.end_of_day
      events = @client.list_events(time_min: time_min, time_max: time_max)

      active_event_ids = []
      created = 0
      updated = 0
      removed = 0
      skipped = 0

      events.each do |event|
        event_id = event["id"].to_s
        next if event_id.blank?

        if cancelled?(event) || owned_by_app?(event)
          skipped += 1
          next
        end

        range = event_date_range(event)
        if range.nil?
          skipped += 1
          next
        end

        active_event_ids << event_id
        booking = Booking.find_by(google_event_id: event_id)

        if booking
          updated += 1 if update_booking!(booking, range, event)
        else
          created += 1 if create_booking!(event_id, range, event)
        end
      end

      removed += remove_stale_bookings!(active_event_ids, time_min.to_date, time_max.to_date)

      { created: created, updated: updated, removed: removed, skipped: skipped }
    end

    private

    def cancelled?(event)
      event["status"].to_s == "cancelled"
    end

    def owned_by_app?(event)
      event.dig("extendedProperties", "private", "cowork_booking_id").present?
    end

    def event_date_range(event)
      start_raw = event.dig("start", "date").presence || event.dig("start", "dateTime")
      end_raw = event.dig("end", "date").presence || event.dig("end", "dateTime")
      return nil if start_raw.blank? || end_raw.blank?

      if event.dig("start", "date").present?
        starts_on = Date.parse(start_raw)
        # Google all-day end.date is exclusive.
        ends_on = Date.parse(end_raw) - 1.day
      else
        starts_on = Time.zone.parse(start_raw).to_date
        ends_on = Time.zone.parse(end_raw).to_date
        ends_on -= 1.day if Time.zone.parse(end_raw).seconds_since_midnight.zero? && ends_on > starts_on
      end

      return nil if ends_on < starts_on
      return nil if ends_on < Date.current

      starts_on = [ starts_on, Date.current ].max
      { starts_on: starts_on, ends_on: ends_on }
    rescue ArgumentError, TypeError
      nil
    end

    def create_booking!(event_id, range, event)
      seat = first_available_seat(range)
      unless seat
        Rails.logger.warn(
          "GoogleCalendar::InboundSync no desk available for event #{event_id} " \
          "(#{range[:starts_on]}..#{range[:ends_on]})"
        )
        return false
      end

      attrs = booking_attrs(range).merge(
        user: SystemUser.call,
        seat: seat,
        google_event_id: event_id,
        source: "google_calendar"
      )

      booking = nil
      ActiveRecord::Base.transaction do
        Seat.lock.find(seat.id)
        unless seat_still_available?(seat, range)
          Rails.logger.warn("GoogleCalendar::InboundSync seat #{seat.code} taken while creating event #{event_id}")
          return false
        end
        booking = Booking.create!(attrs)
      end

      issue_access_code!(booking.user)
      true
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
      Rails.logger.error("GoogleCalendar::InboundSync create failed for #{event_id}: #{e.class}: #{e.message}")
      false
    end

    def update_booking!(booking, range, event)
      return false unless booking.source == "google_calendar"

      attrs = booking_attrs(range)
      return false if booking.date == attrs[:date] &&
        booking.starts_on == attrs[:starts_on] &&
        booking.ends_on == attrs[:ends_on] &&
        booking.booking_type == attrs[:booking_type]

      unless seat_still_available?(booking.seat, range, except_booking: booking)
        seat = first_available_seat(range, except_booking: booking)
        unless seat
          Rails.logger.warn("GoogleCalendar::InboundSync cannot move booking #{booking.id}; no desk free")
          return false
        end
        attrs[:seat] = seat
      end

      booking.update!(attrs)
      true
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("GoogleCalendar::InboundSync update failed for booking #{booking.id}: #{e.class}: #{e.message}")
      false
    end

    def remove_stale_bookings!(active_event_ids, from_date, to_date)
      scope = Booking.where(source: "google_calendar").where.not(google_event_id: nil)
      scope = scope.where(
        "(booking_type = 'daily' AND date BETWEEN :from AND :to) OR " \
        "(booking_type = 'monthly' AND starts_on <= :to AND ends_on >= :from)",
        from: from_date, to: to_date
      )

      removed = 0
      scope.find_each do |booking|
        next if active_event_ids.include?(booking.google_event_id)

        revoke_access_if_needed!(booking)
        booking.destroy!
        removed += 1
      rescue StandardError => e
        Rails.logger.error(
          "GoogleCalendar::InboundSync destroy failed for booking #{booking.id}: #{e.class}: #{e.message}"
        )
      end
      removed
    end

    def booking_attrs(range)
      if range[:starts_on] == range[:ends_on]
        { booking_type: "daily", date: range[:starts_on], starts_on: nil, ends_on: nil }
      else
        { booking_type: "monthly", date: nil, starts_on: range[:starts_on], ends_on: range[:ends_on] }
      end
    end

    def first_available_seat(range, except_booking: nil)
      Seat.desks.ordered.find do |seat|
        seat_still_available?(seat, range, except_booking: except_booking)
      end
    end

    def seat_still_available?(seat, range, except_booking: nil)
      if range[:starts_on] == range[:ends_on]
        SeatAvailability.available_on?(
          seat, range[:starts_on],
          except_booking: except_booking,
          ignore_pending: true
        )
      else
        SeatAvailability.available_for_monthly?(
          seat, range[:starts_on], range[:ends_on],
          except_booking: except_booking,
          ignore_pending: true
        )
      end
    end

    def issue_access_code!(user)
      TtLock::AccessCodeIssuer.issue_for_user!(user)
    rescue StandardError => e
      Rails.logger.error("Access code issue failed for Croissant user #{user.id}: #{e.class}: #{e.message}")
    end

    def revoke_access_if_needed!(booking)
      access_code = booking.access_code || booking.user&.access_code
      return unless access_code
      return if booking.user.bookings.upcoming.where.not(id: booking.id).exists?

      TtLock::AccessCodeRevoker.call(access_code)
    rescue StandardError => e
      Rails.logger.error("Access code revoke failed for booking #{booking.id}: #{e.class}: #{e.message}")
    end
  end
end
